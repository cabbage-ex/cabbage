defmodule Cabbage.Conformance.CCK.Steps do
  @moduledoc """
  Elixir step definitions for the CCK sample features, re-implemented from the upstream
  reference TypeScript (`test/conformance/cck/reference/<name>/<name>.ts`).

  Each public function returns a populated `Cabbage.Messages.StepRegistry` for one sample
  area. The `for/1` dispatcher maps a sample name to its registry; `sample_uri/2` mirrors
  the `samples/<name>/<file>` uri the goldens embed (dropped by normalization, but kept
  realistic). These are test fixtures, not shipped library code.

  Step outcome protocol (see `Cabbage.Messages`): returning `"pending"`/`"skipped"` sets
  that status (no exception); raising `Cabbage.PendingError`/`Cabbage.SkippedError` sets
  PENDING/SKIPPED *with* the reference exception type; raising anything else marks the
  step FAILED; anything else PASSES. `{:ok, world}` threads scenario world state across
  steps.
  """

  alias Cabbage.Messages.{Attach, HookRegistry, StepRegistry}

  # Vendored binary attachments live alongside the goldens under data/<sample>/.
  @data_dir Path.join([__DIR__, "data"])

  @doc "The step registry for `sample`, or an empty registry when the sample has no step defs."
  @spec for(String.t()) :: StepRegistry.t()
  def for(sample)

  def for("minimal") do
    StepRegistry.new()
    |> add("I have {int} cukes in my belly", "minimal", 3, fn _args -> :ok end)
  end

  def for("empty"), do: StepRegistry.new()

  def for("cdata") do
    StepRegistry.new()
    |> add("I have {int} <![CDATA[cukes]]> in my belly", "cdata", 3, fn _args -> :ok end)
  end

  def for("backgrounds") do
    StepRegistry.new()
    |> add("an order for {string}", "backgrounds", 3, fn _ -> :ok end)
    |> add("an action", "backgrounds", 7, fn -> :ok end)
    |> add("an outcome", "backgrounds", 11, fn -> :ok end)
  end

  def for("rules-backgrounds") do
    StepRegistry.new()
    |> add("an order for {string}", "rules-backgrounds", 3, fn _ -> :ok end)
    |> add("an action", "rules-backgrounds", 7, fn -> :ok end)
    |> add("an outcome", "rules-backgrounds", 11, fn -> :ok end)
  end

  def for("doc-strings") do
    StepRegistry.new()
    |> add("a doc string:", "doc-strings", 3, fn _args, _arg -> :ok end)
  end

  def for("data-tables") do
    StepRegistry.new()
    |> add("the following table is transposed:", "data-tables", 6, fn _args, {:data_table, rows}, world ->
      {:ok, Map.put(world, :transposed, transpose(rows))}
    end)
    |> add("it should be:", "data-tables", 10, fn _args, {:data_table, expected}, world ->
      ^expected = Map.fetch!(world, :transposed)
      :ok
    end)
  end

  def for("unused-steps") do
    StepRegistry.new()
    |> add("a step that is used", "unused-steps", 3, fn -> :ok end)
    |> add("a step that is not used", "unused-steps", 7, fn -> :ok end)
  end

  def for("undefined") do
    StepRegistry.new()
    |> add("an implemented step", "undefined", 3, fn -> :ok end)
    |> add("a step that will be skipped", "undefined", 7, fn -> :ok end)
  end

  def for("pending") do
    StepRegistry.new()
    |> add("an implemented non-pending step", "pending", 3, fn -> :ok end)
    |> add("an implemented step that is skipped", "pending", 7, fn -> :ok end)
    |> add("an unimplemented pending step", "pending", 11, fn -> "pending" end)
  end

  def for("skipped") do
    StepRegistry.new()
    |> add("a step that does not skip", "skipped", 3, fn -> :ok end)
    |> add("a step that is skipped", "skipped", 7, fn -> :ok end)
    |> add("I skip a step", "skipped", 11, fn -> "skipped" end)
  end

  def for("ambiguous") do
    StepRegistry.new()
    |> add(~r/^a (.*?) with (.*?)$/, "ambiguous", 3, fn _args -> :ok end)
    |> add(~r/^a step with (.*?)$/, "ambiguous", 7, fn _args -> :ok end)
  end

  def for("rules") do
    StepRegistry.new()
    |> add("the customer has {int} cents", "rules", 5, fn [money], _arg, world ->
      {:ok, Map.put(world, :money, money)}
    end)
    |> add("there are chocolate bars in stock", "rules", 9, fn _args, _arg, world ->
      {:ok, Map.put(world, :stock, ["Mars"])}
    end)
    |> add("there are no chocolate bars in stock", "rules", 13, fn _args, _arg, world ->
      {:ok, Map.put(world, :stock, [])}
    end)
    |> add("the customer tries to buy a {int} cent chocolate bar", "rules", 17, fn [price], _arg, world ->
      money = Map.get(world, :money, 0)
      stock = Map.get(world, :stock, [])

      if money >= price and stock != [] do
        {:ok, Map.put(world, :chocolate, hd(stock))}
      else
        :ok
      end
    end)
    |> add("the sale should not happen", "rules", 22, fn _args, _arg, world ->
      nil = Map.get(world, :chocolate)
      :ok
    end)
    |> add("the sale should happen", "rules", 26, fn _args, _arg, world ->
      true = Map.get(world, :chocolate) != nil
      :ok
    end)
  end

  def for("examples-tables") do
    StepRegistry.new()
    |> add("there are {int} cucumbers", "examples-tables", 4, fn [count], _arg, world ->
      {:ok, Map.put(world, :count, count)}
    end)
    |> add("there are {int} friends", "examples-tables", 8, fn [friends], _arg, world ->
      {:ok, Map.put(world, :friends, friends)}
    end)
    |> add("I eat {int} cucumbers", "examples-tables", 12, fn [eaten], _arg, world ->
      {:ok, Map.update!(world, :count, &(&1 - eaten))}
    end)
    |> add("I should have {int} cucumbers", "examples-tables", 16, fn [expected], _arg, world ->
      ^expected = Map.fetch!(world, :count)
      :ok
    end)
    |> add("each person can eat {int} cucumbers", "examples-tables", 20, fn [expected], _arg, world ->
      share = div(Map.fetch!(world, :count), 1 + Map.fetch!(world, :friends))
      ^expected = share
      :ok
    end)
  end

  # All three steps take an {int}, but the outline placeholders are substituted with
  # non-integer Examples values (`pear`, `banana`, `apple`), so for each row exactly one
  # expanded step text fails to match a definition and stays UNDEFINED (skipping the rest
  # of that scenario). Definition lines mirror the reference `.ts` (4, 8, 12).
  def for("examples-tables-undefined") do
    StepRegistry.new()
    |> add("there are {int} cucumbers", "examples-tables-undefined", 4, fn [count], _arg, world ->
      {:ok, Map.put(world, :count, count)}
    end)
    |> add("I eat {int} cucumbers", "examples-tables-undefined", 8, fn [eaten], _arg, world ->
      {:ok, Map.update!(world, :count, &(&1 - eaten))}
    end)
    |> add("I should have {int} cucumbers", "examples-tables-undefined", 12, fn [expected], _arg, world ->
      ^expected = Map.fetch!(world, :count)
      :ok
    end)
  end

  def for("markdown") do
    StepRegistry.new()
    |> add("some TypeScript code:", "markdown", 4, fn _args, _arg -> :ok end)
    |> add("some classic Gherkin:", "markdown", 8, fn _args, _arg -> :ok end)
    |> add(
      "we use a data table and attach something and then {word}",
      "markdown",
      11,
      fn [word], _arg, world ->
        Attach.log(world, "We are logging some plain text (#{word})")
        if word == "fail", do: raise("You asked me to fail"), else: :ok
      end
    )
    |> add("this might or might not run", "markdown", 22, fn -> :ok end)
  end

  def for("multiple-features") do
    StepRegistry.new()
    |> add("an order for {string}", "multiple-features", 3, fn _args -> :ok end)
  end

  def for("multiple-features-reversed") do
    StepRegistry.new()
    |> add("an order for {string}", "multiple-features-reversed", 3, fn _args -> :ok end)
  end

  def for("all-statuses") do
    StepRegistry.new()
    |> add(~r/^a step$/, "all-statuses", 3, fn _args -> :ok end)
    |> add(~r/^a failing step$/, "all-statuses", 5, fn _args -> raise "whoops" end)
    |> add(~r/^a pending step$/, "all-statuses", 9, fn _args -> "pending" end)
    |> add(~r/^a skipped step$/, "all-statuses", 13, fn _args -> "skipped" end)
    |> add(~r/^an ambiguous (.*?)$/, "all-statuses", 17, fn _args -> :ok end)
    |> add(~r/^(.*?) ambiguous step$/, "all-statuses", 19, fn _args -> :ok end)
  end

  def for("failedish-combinations") do
    StepRegistry.new()
    |> add(~r/^a step$/, "failedish-combinations", 3, fn _args -> :ok end)
    |> add(~r/^a skipped step$/, "failedish-combinations", 7, fn _args -> "skipped" end)
    |> add(~r/^a pending step$/, "failedish-combinations", 11, fn _args -> "pending" end)
    |> add(~r/^an ambiguous (.*?)$/, "failedish-combinations", 15, fn _args -> :ok end)
    |> add(~r/^(.*?) ambiguous step$/, "failedish-combinations", 17, fn _args -> :ok end)
    |> add(~r/^a failing step$/, "failedish-combinations", 19, fn _args -> raise "whoops" end)
  end

  def for("stack-traces") do
    StepRegistry.new()
    |> add("a step throws an exception", "stack-traces", 3, fn -> raise "BOOM" end)
  end

  def for("pending-exception") do
    StepRegistry.new()
    |> add("an unimplemented pending step", "pending-exception", 3, fn ->
      raise Cabbage.PendingError, "TODO"
    end)
  end

  def for("skipped-exception") do
    StepRegistry.new()
    |> add("I skip a step", "skipped-exception", 3, fn ->
      raise Cabbage.SkippedError, "skipping"
    end)
  end

  def for("parameter-types") do
    # A custom `{flight}` parameter type (LHR-CDG) with a transformer, mirroring the
    # reference `ParameterType({ name: 'flight', regexp: /([A-Z]{3})-([A-Z]{3})/, ... })`.
    StepRegistry.new()
    |> StepRegistry.define_parameter_type(
      name: "flight",
      regexp: ~r/([A-Z]{3})-([A-Z]{3})/,
      transform: fn [from, to] -> %{from: from, to: to} end,
      uri: "samples/parameter-types/parameter-types.ts",
      line: 11
    )
    |> add("{flight} has been delayed", "parameter-types", 19, fn [flight] ->
      %{from: "LHR", to: "CDG"} = flight
      :ok
    end)
  end

  def for("regular-expression") do
    # A step definition defined by a *regular expression* (not a Cucumber Expression),
    # with three optional capture groups.
    StepRegistry.new()
    |> add(
      ~r/^a (.*?)(?: and a (.*?))?(?: and a (.*?))?$/,
      "regular-expression",
      3,
      fn _args -> :ok end
    )
  end

  def for("unknown-parameter-type") do
    # The step references an UNDEFINED `{airport}` parameter type. Registration must not
    # crash: the def becomes undefined (the step is UNDEFINED) and an
    # undefinedParameterType message is emitted. The body would raise if ever called.
    StepRegistry.new()
    |> add("{airport} is closed because of a strike", "unknown-parameter-type", 3, fn _args ->
      raise "Should not be called because airport parameter type has not been defined"
    end)
  end

  # ---- attachment areas (step definitions) -----------------------------------

  def for("attachments") do
    StepRegistry.new()
    |> add("the string {string} is attached as {string}", "attachments", 4, fn [text, media_type], _arg, world ->
      Attach.attach(world, text, media_type)
    end)
    |> add("the string {string} is logged", "attachments", 11, fn [text], _arg, world ->
      Attach.log(world, text)
    end)
    |> add("text with ANSI escapes is logged", "attachments", 15, fn _args, _arg, world ->
      Attach.log(
        world,
        "This displays a \e[31mr\e[0m\e[91ma\e[0m\e[33mi\e[0m\e[32mn\e[0m\e[34mb\e[0m\e[95mo\e[0m\e[35mw\e[0m"
      )
    end)
    |> add("the following string is attached as {string}:", "attachments", 21, fn [media_type],
                                                                                  {:doc_string, text},
                                                                                  world ->
      Attach.attach(world, text, media_type)
    end)
    |> add("an array with {int} bytes is attached as {string}", "attachments", 28, fn [size, media_type], _arg, world ->
      bytes = :erlang.list_to_binary(Enum.to_list(0..(size - 1)))
      Attach.attach(world, {:bytes, bytes}, media_type)
    end)
    |> add("a PDF document is attached and renamed", "attachments", 37, fn _args, _arg, world ->
      Attach.attach(world, {:bytes, binary("attachments", "document.pdf")},
        media_type: "application/pdf",
        file_name: "renamed.pdf"
      )
    end)
    |> add("a link to {string} is attached", "attachments", 44, fn [uri], _arg, world ->
      Attach.link(world, uri)
    end)
    |> add("the string {string} is attached as {string} before a failure", "attachments", 48, fn [text, media_type],
                                                                                                 _arg,
                                                                                                 world ->
      Attach.attach(world, text, media_type)
      raise "whoops"
    end)
  end

  def for("examples-tables-attachment") do
    StepRegistry.new()
    |> add("a JPEG image is attached", "examples-tables-attachment", 4, fn _args, _arg, world ->
      Attach.attach(world, {:bytes, binary("examples-tables-attachment", "cucumber.jpeg")}, "image/jpeg")
    end)
    |> add("a PNG image is attached", "examples-tables-attachment", 8, fn _args, _arg, world ->
      Attach.attach(world, {:bytes, binary("examples-tables-attachment", "cucumber.png")}, "image/png")
    end)
  end

  def for("hooks-attachment") do
    StepRegistry.new()
    |> add("a step passes", "hooks-attachment", 9, fn -> :ok end)
  end

  def for("global-hooks-attachments") do
    StepRegistry.new()
    |> add("a step passes", "global-hooks-attachments", 7, fn -> :ok end)
  end

  # ---- hook areas (step definitions) -----------------------------------------

  def for("hooks") do
    StepRegistry.new()
    |> add("a step passes", "hooks", 7, fn -> :ok end)
    |> add("a step fails", "hooks", 11, fn -> raise "Exception in step" end)
  end

  def for("hooks-named") do
    StepRegistry.new()
    |> add("a step passes", "hooks-named", 7, fn -> :ok end)
  end

  def for("hooks-conditional") do
    StepRegistry.new()
    |> add("a step passes", "hooks-conditional", 11, fn -> :ok end)
  end

  def for("hooks-skipped") do
    StepRegistry.new()
    |> add("a normal step", "hooks-skipped", 13, fn -> :ok end)
    |> add("a step that skips", "hooks-skipped", 17, fn -> "skipped" end)
  end

  def for("hooks-undefined"), do: StepRegistry.new()

  def for("global-hooks") do
    StepRegistry.new()
    |> add("a step passes", "global-hooks", 11, fn -> :ok end)
    |> add("a step fails", "global-hooks", 15, fn -> raise "Exception in step" end)
  end

  def for("global-hooks-beforeall-error") do
    StepRegistry.new()
    |> add("a step passes", "global-hooks-beforeall-error", 15, fn -> :ok end)
  end

  def for("global-hooks-afterall-error") do
    StepRegistry.new()
    |> add("a step passes", "global-hooks-afterall-error", 11, fn -> :ok end)
  end

  def for("skipped-failing-hook") do
    StepRegistry.new()
    |> add("a step that skips", "skipped-failing-hook", 3, fn -> "skipped" end)
  end

  # ---- retry areas (step definitions) ----------------------------------------

  # The reference `retry.ts` tracks per-step attempt counts in module-level `let`s; here
  # each is a fresh per-run Agent so a step "passes the Nth time" by raising on the first
  # N-1 attempts. `Steps.for/1` is called once per run, so the counters reset per run while
  # persisting across the retry loop's attempts.
  def for("retry") do
    second_time = passes_after(1)
    third_time = passes_after(2)

    StepRegistry.new()
    |> add("a step that always passes", "retry", 3, fn -> :ok end)
    |> add("a step that passes the second time", "retry", 8, second_time)
    |> add("a step that passes the third time", "retry", 16, third_time)
    |> add("a step that always fails", "retry", 23, fn -> raise "Exception in step" end)
  end

  # AMBIGUOUS does not retry: two definitions match the same step.
  def for("retry-ambiguous") do
    StepRegistry.new()
    |> add("an ambiguous step", "retry-ambiguous", 3, fn -> :ok end)
    |> add("an ambiguous step", "retry-ambiguous", 7, fn -> :ok end)
  end

  # PENDING does not retry.
  def for("retry-pending") do
    StepRegistry.new()
    |> add("a pending step", "retry-pending", 3, fn -> "pending" end)
  end

  # UNDEFINED does not retry: no step definitions at all (the step stays undefined).
  def for("retry-undefined"), do: StepRegistry.new()

  # ---- hook areas (hook registrations) ---------------------------------------

  @doc """
  The hook registry for `sample`, mirroring the reference `Before`/`After`/`BeforeAll`/
  `AfterAll` registrations (registration order is significant — see
  `Cabbage.Messages.HookRegistry`). Samples with no hooks get an empty registry.
  """
  @spec hooks_for(String.t()) :: HookRegistry.t()
  def hooks_for(sample)

  def hooks_for("hooks") do
    HookRegistry.new()
    |> before(fn -> :ok end, "hooks", 3)
    |> aftr(fn -> :ok end, "hooks", 15)
  end

  def hooks_for("hooks-named") do
    HookRegistry.new()
    |> before(fn -> :ok end, "hooks-named", 3, name: "A named before hook")
    |> aftr(fn -> :ok end, "hooks-named", 11, name: "A named after hook")
  end

  def hooks_for("hooks-conditional") do
    HookRegistry.new()
    |> before(fn -> :ok end, "hooks-conditional", 3, tag: "@passing-hook")
    |> before(fn -> raise "Exception in conditional hook" end, "hooks-conditional", 7, tag: "@fail-before")
    |> aftr(fn -> raise "Exception in conditional hook" end, "hooks-conditional", 15, tag: "@fail-after")
    |> aftr(fn -> :ok end, "hooks-conditional", 19, tag: "@passing-hook")
  end

  def hooks_for("hooks-skipped") do
    HookRegistry.new()
    |> before(fn -> :ok end, "hooks-skipped", 3)
    |> before(fn -> "skipped" end, "hooks-skipped", 7, tag: "@skip-before")
    |> before(fn -> :ok end, "hooks-skipped", 9)
    |> aftr(fn -> :ok end, "hooks-skipped", 19)
    |> aftr(fn -> "skipped" end, "hooks-skipped", 23, tag: "@skip-after")
    |> aftr(fn -> :ok end, "hooks-skipped", 25)
  end

  def hooks_for("hooks-undefined") do
    HookRegistry.new()
    |> before(fn -> :ok end, "hooks-undefined", 3)
    |> aftr(fn -> :ok end, "hooks-undefined", 5)
  end

  def hooks_for("global-hooks") do
    HookRegistry.new()
    |> before_all(fn -> :ok end, "global-hooks", 3)
    |> before_all(fn -> :ok end, "global-hooks", 7)
    |> after_all(fn -> :ok end, "global-hooks", 19)
    |> after_all(fn -> :ok end, "global-hooks", 23)
  end

  def hooks_for("global-hooks-beforeall-error") do
    HookRegistry.new()
    |> before_all(fn -> :ok end, "global-hooks-beforeall-error", 3)
    |> before_all(fn -> raise "BeforeAll hook went wrong" end, "global-hooks-beforeall-error", 7)
    |> before_all(fn -> :ok end, "global-hooks-beforeall-error", 11)
    |> after_all(fn -> :ok end, "global-hooks-beforeall-error", 19)
    |> after_all(fn -> :ok end, "global-hooks-beforeall-error", 23)
  end

  def hooks_for("global-hooks-afterall-error") do
    HookRegistry.new()
    |> before_all(fn -> :ok end, "global-hooks-afterall-error", 3)
    |> before_all(fn -> :ok end, "global-hooks-afterall-error", 7)
    |> after_all(fn -> :ok end, "global-hooks-afterall-error", 15)
    |> after_all(fn -> raise "AfterAll hook went wrong" end, "global-hooks-afterall-error", 19)
    |> after_all(fn -> :ok end, "global-hooks-afterall-error", 23)
  end

  def hooks_for("skipped-failing-hook") do
    HookRegistry.new()
    |> aftr(fn -> raise "whoops" end, "skipped-failing-hook", 5)
  end

  def hooks_for("hooks-attachment") do
    svg = binary("hooks-attachment", "cucumber.svg")

    HookRegistry.new()
    |> before(fn _args, _arg, world -> Attach.attach(world, {:bytes, svg}, "image/svg+xml") end, "hooks-attachment", 4)
    |> aftr(fn _args, _arg, world -> Attach.attach(world, {:bytes, svg}, "image/svg+xml") end, "hooks-attachment", 12)
  end

  def hooks_for("global-hooks-attachments") do
    HookRegistry.new()
    |> before_all(
      fn _args, _arg, world -> Attach.attach(world, "Attachment from BeforeAll hook", "text/plain") end,
      "global-hooks-attachments",
      3
    )
    |> after_all(
      fn _args, _arg, world -> Attach.attach(world, "Attachment from AfterAll hook", "text/plain") end,
      "global-hooks-attachments",
      11
    )
  end

  def hooks_for(_sample), do: HookRegistry.new()

  # ---- helpers ---------------------------------------------------------------

  defp add(registry, pattern, sample, line, fun) do
    uri = "samples/#{sample}/#{sample}.ts"
    StepRegistry.add(registry, pattern, fun, uri: uri, line: line)
  end

  defp before(registry, fun, sample, line, opts \\ []),
    do: hook(registry, :before_test_case, fun, sample, line, opts)

  defp aftr(registry, fun, sample, line, opts \\ []),
    do: hook(registry, :after_test_case, fun, sample, line, opts)

  defp before_all(registry, fun, sample, line, opts \\ []),
    do: hook(registry, :before_test_run, fun, sample, line, opts)

  defp after_all(registry, fun, sample, line, opts \\ []),
    do: hook(registry, :after_test_run, fun, sample, line, opts)

  defp hook(registry, type, fun, sample, line, opts) do
    uri = "samples/#{sample}/#{sample}.ts"
    HookRegistry.add(registry, type, fun, Keyword.merge([uri: uri, line: line], opts))
  end

  # Read a vendored binary attachment fixture (alongside the sample's golden) as raw bytes.
  defp binary(sample, file), do: File.read!(Path.join([@data_dir, sample, file]))

  # A 0-arity step fun that raises on its first `fail_count` invocations and passes after,
  # backed by a fresh per-run Agent counter (mirroring the reference's module-level `let`).
  # `passes_after(1)` passes on the 2nd attempt; `passes_after(2)` on the 3rd.
  defp passes_after(fail_count) do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    fn ->
      n = Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)
      if n <= fail_count, do: raise("Exception in step"), else: :ok
    end
  end

  # Transpose a list of rows (each a list of cell strings), matching DataTable#transpose.
  defp transpose([]), do: []
  defp transpose(rows), do: rows |> Enum.zip() |> Enum.map(&Tuple.to_list/1)
end
