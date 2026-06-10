Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FormatterTest do
  use ExUnit.Case

  alias Cabbage.Messages.Normalizer

  # Runs a list of feature modules under a fresh ExUnit run that includes
  # `Cabbage.Formatter`, writing the cucumber-messages stream to a temp file.
  # Returns the parsed (one map per line) envelope list.
  defp run_with_formatter(modules, filters \\ []) do
    path = Path.join(System.tmp_dir!(), "cabbage-formatter-#{System.unique_integer([:positive])}.ndjson")
    on_exit(fn -> File.rm(path) end)

    previous = Application.get_env(:cabbage, :messages_output)
    Application.put_env(:cabbage, :messages_output, path)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:cabbage, :messages_output, previous),
        else: Application.delete_env(:cabbage, :messages_output)
    end)

    {_result, _output} =
      CabbageTestHelper.run([formatters: [Cabbage.Formatter]] ++ filters, modules)

    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(&decode_line/1)
  end

  defp decode_line(line) do
    case JSON.decode(line) do
      {:ok, map} -> map
      decoded when is_map(decoded) -> decoded
    end
  end

  defp types(envelopes), do: Enum.flat_map(envelopes, &Map.keys/1)

  defp statuses(envelopes) do
    envelopes
    |> Enum.filter(&Map.has_key?(&1, "testStepFinished"))
    |> Enum.map(&get_in(&1, ["testStepFinished", "testStepResult", "status"]))
  end

  describe "passing scenario" do
    test "emits a well-ordered envelope stream with a successful run" do
      defmodule PassingFeature do
        use Cabbage.Feature, file: "simple.feature"

        defgiven(~r/^I provide Given$/, _vars, _state, do: :ok)
        defgiven(~r/^I provide And$/, _vars, _state, do: :ok)
        defwhen(~r/^I provide When$/, _vars, _state, do: :ok)

        defthen ~r/^I provide Then$/, _vars, _state do
          assert true
          :ok
        end
      end

      envelopes = run_with_formatter([PassingFeature])
      present = types(envelopes)

      # Required floor: meta, parser-side, run-structure and scenario envelopes.
      assert "meta" in present
      assert "source" in present
      assert "gherkinDocument" in present
      assert "pickle" in present
      assert "testRunStarted" in present
      assert "testCase" in present
      assert "testCaseStarted" in present
      assert "testCaseFinished" in present
      assert "testRunFinished" in present

      # `meta` is first; `testRunStarted` precedes any `testCaseStarted`; `testRunFinished` last.
      assert hd(present) == "meta"

      assert Enum.find_index(present, &(&1 == "testRunStarted")) <
               Enum.find_index(present, &(&1 == "testCaseStarted"))

      assert List.last(present) == "testRunFinished"

      # A passing scenario yields a successful run.
      run_finished = Enum.find(envelopes, &Map.has_key?(&1, "testRunFinished"))
      assert get_in(run_finished, ["testRunFinished", "success"]) == true
    end

    test "the emitted stream is valid cucumber-messages (normalizes without raising)" do
      defmodule NormalizableFeature do
        use Cabbage.Feature, file: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          assert true
          :ok
        end
      end

      envelopes = run_with_formatter([NormalizableFeature])
      normalized = Normalizer.normalize(envelopes)

      # meta is dropped by normalization; everything else survives as comparable maps.
      assert is_list(normalized)
      refute Enum.any?(normalized, &Map.has_key?(&1, "meta"))
      assert Enum.any?(normalized, &Map.has_key?(&1, "testRunFinished"))
    end
  end

  describe "failing scenario" do
    test "marks the scenario FAILED and the run unsuccessful" do
      defmodule FailingFeature do
        use Cabbage.Feature, file: "simplest.feature"

        defthen(~r/^I provide Then$/, _vars, _state, do: assert(1 == 2))
      end

      envelopes = run_with_formatter([FailingFeature])

      # Cabbage runs every step inside one ExUnit test, so step results are attributed
      # uniformly from the scenario outcome (see Cabbage.Formatter docs).
      assert "FAILED" in statuses(envelopes)

      run_finished = Enum.find(envelopes, &Map.has_key?(&1, "testRunFinished"))
      assert get_in(run_finished, ["testRunFinished", "success"]) == false
    end
  end

  describe "testCase planning and per-step events" do
    test "lists one testStep per scenario step and emits matching step events" do
      defmodule TestStepsFeature do
        use Cabbage.Feature, file: "simple.feature"

        defgiven(~r/^I provide Given$/, _vars, _state, do: :ok)
        defgiven(~r/^I provide And$/, _vars, _state, do: :ok)
        defwhen(~r/^I provide When$/, _vars, _state, do: :ok)

        defthen ~r/^I provide Then$/, _vars, _state do
          assert true
          :ok
        end
      end

      envelopes = run_with_formatter([TestStepsFeature])
      test_case = Enum.find(envelopes, &Map.has_key?(&1, "testCase"))

      # simple.feature has four steps (Given, And, When, Then).
      assert length(get_in(test_case, ["testCase", "testSteps"])) == 4
      assert Enum.count(envelopes, &Map.has_key?(&1, "testStepStarted")) == 4
      assert Enum.count(envelopes, &Map.has_key?(&1, "testStepFinished")) == 4
      assert statuses(envelopes) == ~w(PASSED PASSED PASSED PASSED)
    end
  end
end
