defmodule Cabbage.Messages.Normalizer do
  @moduledoc """
  Normalizes a cucumber-messages envelope stream so two implementations can be compared
  for conformance. This is a faithful port of the comparison cucumber-js performs in
  `compatibility/cck_spec.ts` + `features/support/formatter_output_helpers.ts`.

  Comparison drops all non-deterministic data, then requires deep equality with the
  envelope **count, type and order preserved**. The steps, applied in order:

    1. **Drop the entire `meta` envelope** (implementation/CI/OS noise).
    2. **Recursively delete the `ignorable` keys everywhere** — ids, uris, line numbers,
       timestamps, and language-specific text (`message`, `stackTrace`, `code`, `language`).
    3. **Reorder** any `testRunHookStarted`/`testRunHookFinished` occurring *before* the
       first `testCaseStarted` to immediately follow `testRunStarted`.
    4. **Sort the unordered groups**: `stepDefinition` envelopes by their pattern source,
       and `hook` envelopes by type then tag expression (mirroring cucumber-jvm).

  The result is a list of normalized envelope maps ready for `==` comparison.
  """

  @ignorable_keys ~w(
    uri line astNodeId astNodeIds hookId id pickleId pickleStepId stepDefinitionIds
    testRunStartedId testRunHookStartedId testCaseId testCaseStartedId testStepId
    nanos seconds message stackTrace language code
  )

  @doc "Normalize an envelope list (count/type/order-preserving, value-dropping)."
  @spec normalize([map()]) :: [map()]
  def normalize(envelopes) when is_list(envelopes) do
    envelopes
    |> Enum.reject(&envelope?(&1, "meta"))
    |> Enum.map(&drop_ignorable/1)
    |> reorder_envelopes()
    |> sort_unordered_groups()
  end

  # ---- 2. recursive ignorable-key drop ---------------------------------------

  defp drop_ignorable(map) when is_map(map) and not is_struct(map) do
    map
    |> Enum.reject(fn {k, _v} -> to_string(k) in @ignorable_keys end)
    |> Enum.map(fn {k, v} -> {k, drop_ignorable(v)} end)
    |> Map.new()
  end

  defp drop_ignorable(list) when is_list(list), do: Enum.map(list, &drop_ignorable/1)
  defp drop_ignorable(other), do: other

  # ---- 3. reorder testRunHook envelopes --------------------------------------

  # Any testRunHookStarted/Finished occurring before the first testCaseStarted is moved to
  # immediately after testRunStarted, preserving their relative order. This is the
  # BeforeAll-hook block: cabbage already emits it right after testRunStarted, but some
  # reference goldens place those envelopes elsewhere in the pre-test-case prefix, so this
  # canonicalizes both streams to the same position before the order-sensitive comparison.
  defp reorder_envelopes(envelopes) do
    first_case_index =
      Enum.find_index(envelopes, &envelope?(&1, "testCaseStarted"))

    case first_case_index do
      nil ->
        envelopes

      index ->
        {before_first_case, rest} = Enum.split(envelopes, index)

        {hooks, others} =
          Enum.split_with(before_first_case, fn env ->
            envelope?(env, "testRunHookStarted") or envelope?(env, "testRunHookFinished")
          end)

        if hooks == [] do
          envelopes
        else
          run_started_index = Enum.find_index(others, &envelope?(&1, "testRunStarted"))
          insert_after(others, run_started_index, hooks) ++ rest
        end
    end
  end

  defp insert_after(list, nil, hooks), do: hooks ++ list

  defp insert_after(list, index, hooks) do
    {head, tail} = Enum.split(list, index + 1)
    head ++ hooks ++ tail
  end

  # ---- 4. sort unordered groups ----------------------------------------------

  # stepDefinition and hook envelopes form contiguous, order-insensitive blocks. We sort
  # each maximal run in place (by pattern source / hook key) without disturbing surrounding
  # envelopes, so counts and the position of the block are preserved.
  defp sort_unordered_groups(envelopes) do
    envelopes
    |> sort_runs("stepDefinition", &step_definition_key/1)
    |> sort_runs("hook", &hook_key/1)
  end

  defp sort_runs(envelopes, key, sort_key_fun) do
    envelopes
    |> chunk_by_membership(key)
    |> Enum.flat_map(fn
      {:member, run} -> Enum.sort_by(run, sort_key_fun)
      {:other, run} -> run
    end)
  end

  # Group consecutive envelopes by whether they belong to `key`, preserving order.
  defp chunk_by_membership(envelopes, key) do
    envelopes
    |> Enum.chunk_by(&envelope?(&1, key))
    |> Enum.map(fn [first | _] = run ->
      if envelope?(first, key), do: {:member, run}, else: {:other, run}
    end)
  end

  defp step_definition_key(%{"stepDefinition" => %{"pattern" => %{"source" => source}}}), do: source
  defp step_definition_key(_), do: ""

  defp hook_key(%{"hook" => hook}) do
    {Map.get(hook, "type", ""), Map.get(hook, "tagExpression", "")}
  end

  defp hook_key(_), do: {"", ""}

  # ---- helpers ---------------------------------------------------------------

  defp envelope?(map, key) when is_map(map), do: Map.has_key?(map, key)
  defp envelope?(_other, _key), do: false
end
