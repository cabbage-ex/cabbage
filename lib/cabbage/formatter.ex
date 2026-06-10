defmodule Cabbage.Formatter do
  @moduledoc """
  An ExUnit formatter that emits a [cucumber-messages](https://github.com/cucumber/messages)
  NDJSON stream for the `Cabbage.Feature` scenarios in a normal `mix test` run.

  `Cabbage.Feature` compiles each Gherkin scenario into one ExUnit test. This formatter
  observes the ExUnit run as a `GenServer` (the formatter contract — a series of `{event,
  payload}` casts) and, for every cabbage scenario test, writes the envelopes a Cucumber
  consumer expects:

      meta
      source            \\
      gherkinDocument    > once per .feature file (the first time one of its scenarios runs)
      pickle*           /
      testRunStarted
      testCase           \\
      testCaseStarted     |
      testStepStarted     | once per scenario, in test-completion order
      testStepFinished    |
      testCaseFinished   /
      testRunFinished

  It reuses the gherkin dependency's `Gherkin.Message` builders for the parser-side
  envelopes (`source`/`gherkinDocument`/`pickle`) and `Gherkin.parse!/2`/`Gherkin.pickles/2`
  to resolve a feature file to its document and pickles, so the message schema is never
  re-implemented here.

  ## Enabling it

  Add the formatter alongside the default CLI formatter in `test/test_helper.exs`:

      ExUnit.start(formatters: [ExUnit.CLIFormatter, Cabbage.Formatter])

  ## Output location

  The stream is written to `config :cabbage, :messages_output` (default
  `"cucumber-messages.ndjson"` in the project root). Pass `:messages_output` directly in
  the formatter's options to override per run:

      ExUnit.start(formatters: [ExUnit.CLIFormatter, {Cabbage.Formatter, messages_output: "out.ndjson"}])

  ## Step-result granularity (scenario-level)

  ExUnit only reports pass/fail at the *test* level, and cabbage runs every step of a
  scenario inside a single generated test function (the state-threaded reduce). The
  formatter therefore attributes the scenario's outcome **uniformly** to each step: a
  passing scenario emits all `PASSED` steps; a failing one emits all `FAILED`; a
  skipped/excluded one emits all `SKIPPED`. The run-level `testRunFinished.success` flag is
  exact. Granular per-step attribution (which step failed, later steps `SKIPPED`) would
  require instrumenting the step reduce to record per-step boundaries; that is a deliberate
  follow-up rather than a guess made from the scenario result alone.
  """

  use GenServer

  alias Cabbage.Messages.Ids
  alias Gherkin.Message

  @default_output "cucumber-messages.ndjson"

  defmodule State do
    @moduledoc false
    defstruct device: nil, ids: nil, run_started_id: nil, success: true, emitted_uris: MapSet.new()
  end

  @impl GenServer
  def init(opts) do
    path = Keyword.get(opts, :messages_output) || Application.get_env(:cabbage, :messages_output, @default_output)
    device = File.open!(path, [:write, :utf8])

    ids = Ids.new()
    {run_started_id, ids} = Ids.next(ids)

    state = %State{device: device, ids: ids, run_started_id: run_started_id}

    write(state, meta_envelope())
    write(state, test_run_started_envelope(run_started_id))

    {:ok, state}
  end

  @impl GenServer
  def handle_cast({:test_finished, test}, state) do
    {:noreply, maybe_emit_scenario(state, test)}
  end

  def handle_cast({:suite_finished, _times}, state) do
    write(state, test_run_finished_envelope(state.run_started_id, state.success))
    {:noreply, state}
  end

  # Every other formatter event (suite_started, module_*, test_started, sigquit, the
  # deprecated case_*) carries nothing this formatter needs.
  def handle_cast(_event, state), do: {:noreply, state}

  @impl GenServer
  def terminate(_reason, %State{device: device}) when is_pid(device) or is_port(device) do
    File.close(device)
  end

  def terminate(_reason, _state), do: :ok

  # ---- scenario emission -----------------------------------------------------

  defp maybe_emit_scenario(state, %ExUnit.Test{tags: %{test_type: :scenario}, module: module} = test) do
    if function_exported?(module, :__cabbage_document__, 0) do
      emit_scenario(state, test, module.__cabbage_document__())
    else
      state
    end
  end

  defp maybe_emit_scenario(state, _test), do: state

  defp emit_scenario(state, _test, nil), do: state

  defp emit_scenario(state, test, document) do
    case resolve_pickle(document, test) do
      nil ->
        state

      {pickle, format} ->
        state
        |> ensure_parser_envelopes(document, format)
        |> emit_test_case(pickle, test)
    end
  end

  # Re-parse the feature file the module was generated from and pair each pickle with the
  # cabbage scenario sharing its document position, then select the pickle whose scenario
  # name matches this test's `describe` (the disambiguated scenario name cabbage registered).
  defp resolve_pickle(%{file: file} = document, test) when is_binary(file) do
    {source, format} = read_source(file)
    pickles = Gherkin.pickles(source, uri: file)
    scenario_name = test.tags[:describe] || to_string(test.name)

    document.scenarios
    |> Enum.zip(pickles)
    |> Enum.find_value(fn {scenario, pickle} ->
      if scenario.name == scenario_name, do: {pickle, format}
    end)
  end

  defp resolve_pickle(_document, _test), do: nil

  # `.feature.md` files are the Markdown-with-Gherkin dialect; everything else is plain.
  defp read_source(file) do
    source = File.read!(file)
    format = if String.ends_with?(file, ".md"), do: :markdown, else: :plain
    {source, format}
  end

  defp ensure_parser_envelopes(state, %{file: file}, format) do
    if MapSet.member?(state.emitted_uris, file) do
      state
    else
      source = File.read!(file)
      document = Gherkin.parse!(source, uri: file)
      pickles = Gherkin.pickles(source, uri: file)

      write(state, Message.source_envelope(file, source, format))
      write(state, Message.gherkin_document_envelope(document))
      Enum.each(pickles, fn pickle -> write(state, Message.pickle_envelope(pickle)) end)

      %{state | emitted_uris: MapSet.put(state.emitted_uris, file)}
    end
  end

  defp emit_test_case(state, pickle, test) do
    status = status_string(test.state)

    {test_case_id, ids} = Ids.next(state.ids)
    {step_ids, ids} = Enum.map_reduce(pickle.steps, ids, fn _step, ids -> Ids.next(ids) end)

    test_steps = Enum.map(step_ids, fn id -> %{"id" => id} end)
    write(state, test_case_envelope(test_case_id, pickle.id, state.run_started_id, test_steps))

    {test_case_started_id, ids} = Ids.next(ids)
    write(state, test_case_started_envelope(test_case_started_id, test_case_id))

    Enum.each(step_ids, fn step_id ->
      write(state, test_step_started_envelope(test_case_started_id, step_id))
      write(state, test_step_finished_envelope(test_case_started_id, step_id, status))
    end)

    write(state, test_case_finished_envelope(test_case_started_id))

    %{state | ids: ids, success: state.success and success?(status)}
  end

  # ExUnit test state -> cucumber-messages step status. `nil` is a pass; `:invalid` (a failed
  # setup) is treated as a failure; `:excluded`/`:skipped` map to SKIPPED.
  defp status_string(nil), do: "PASSED"
  defp status_string({:failed, _}), do: "FAILED"
  defp status_string({:invalid, _}), do: "FAILED"
  defp status_string({:skipped, _}), do: "SKIPPED"
  defp status_string({:excluded, _}), do: "SKIPPED"
  defp status_string(_other), do: "FAILED"

  defp success?("PASSED"), do: true
  defp success?("SKIPPED"), do: true
  defp success?(_), do: false

  # ---- envelope builders -----------------------------------------------------
  #
  # The run-structure envelopes (`testRunStarted`, `testCase`, ...) are built by private
  # functions inside `Cabbage.Messages`; we re-derive the same shapes here (the parser-side
  # ones are reused from `Gherkin.Message`). Ids/timestamps are dropped by the conformance
  # normalizer, so only their presence matters.

  defp meta_envelope do
    %{
      "meta" => %{
        "protocolVersion" => "31.1.0",
        "implementation" => %{"name" => "cabbage", "version" => cabbage_version()},
        "cpu" => %{"name" => to_string(:erlang.system_info(:system_architecture))},
        "os" => %{"name" => to_string(:os.type() |> elem(1))},
        "runtime" => %{"name" => "Elixir", "version" => System.version()}
      }
    }
  end

  defp cabbage_version do
    case :application.get_key(:cabbage, :vsn) do
      {:ok, vsn} -> to_string(vsn)
      _ -> "0.0.0"
    end
  end

  defp test_run_started_envelope(id) do
    %{"testRunStarted" => %{"id" => id, "timestamp" => timestamp()}}
  end

  defp test_run_finished_envelope(run_started_id, success) do
    %{
      "testRunFinished" => %{
        "testRunStartedId" => run_started_id,
        "timestamp" => timestamp(),
        "success" => success
      }
    }
  end

  defp test_case_envelope(id, pickle_id, run_started_id, test_steps) do
    %{
      "testCase" => %{
        "id" => id,
        "pickleId" => pickle_id,
        "testRunStartedId" => run_started_id,
        "testSteps" => test_steps
      }
    }
  end

  defp test_case_started_envelope(id, test_case_id) do
    %{
      "testCaseStarted" => %{
        "id" => id,
        "testCaseId" => test_case_id,
        "attempt" => 0,
        "timestamp" => timestamp()
      }
    }
  end

  defp test_case_finished_envelope(test_case_started_id) do
    %{
      "testCaseFinished" => %{
        "testCaseStartedId" => test_case_started_id,
        "timestamp" => timestamp(),
        "willBeRetried" => false
      }
    }
  end

  defp test_step_started_envelope(test_case_started_id, test_step_id) do
    %{
      "testStepStarted" => %{
        "testCaseStartedId" => test_case_started_id,
        "testStepId" => test_step_id,
        "timestamp" => timestamp()
      }
    }
  end

  defp test_step_finished_envelope(test_case_started_id, test_step_id, status) do
    %{
      "testStepFinished" => %{
        "testCaseStartedId" => test_case_started_id,
        "testStepId" => test_step_id,
        "testStepResult" => %{"status" => status, "duration" => timestamp()},
        "timestamp" => timestamp()
      }
    }
  end

  defp timestamp, do: %{"seconds" => 0, "nanos" => 0}

  # ---- output ----------------------------------------------------------------

  defp write(%State{device: device}, envelope) do
    IO.write(device, Message.to_ndjson(envelope))
  end
end
