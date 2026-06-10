defmodule Cabbage.MessagesRetryTest do
  @moduledoc """
  Behavioural tests for the retry loop of the message-emitting runner
  (`Cabbage.Messages.run/3` with the `:retry` option).

  These pin the cucumber-messages retry semantics the CCK `retry`, `retry-ambiguous`,
  `retry-pending`, and `retry-undefined` areas require:

    * a `:retry N` option allows a FAILED test case to be re-run up to N additional
      attempts (so up to `N + 1` total attempts);
    * each attempt emits its own `testCaseStarted` with the same `testCaseId` and an
      incrementing 0-based `attempt`, re-emits the per-attempt step envelopes, and a
      `testCaseFinished` whose `willBeRetried` is `true` for every non-final failed
      attempt and `false` for the final attempt;
    * only FAILED triggers a retry — AMBIGUOUS, PENDING, and UNDEFINED do not (they will
      never pass however many times they are attempted), so they run exactly once;
    * a test case that succeeds within the limit stops retrying immediately;
    * `testRunFinished.success` reflects the *final* attempt of each case (a case that
      fails then passes is a successful run; a case that exhausts its retries is not);
    * attachments do not leak across attempts — each attempt drains a clean collector.
  """
  use ExUnit.Case, async: true

  alias Cabbage.Messages
  alias Cabbage.Messages.{Attach, StepRegistry}

  # The per-attempt sequence of `{testCaseId, attempt, willBeRetried}` for each
  # testCaseStarted/testCaseFinished pair, in emission order.
  defp attempts(envelopes) do
    starts =
      envelopes
      |> Enum.filter(&Map.has_key?(&1, "testCaseStarted"))
      |> Enum.map(fn e ->
        s = e["testCaseStarted"]
        {s["id"], s["testCaseId"], s["attempt"]}
      end)

    finishes =
      envelopes
      |> Enum.filter(&Map.has_key?(&1, "testCaseFinished"))
      |> Enum.map(fn e ->
        f = e["testCaseFinished"]
        {f["testCaseStartedId"], f["willBeRetried"]}
      end)
      |> Map.new()

    Enum.map(starts, fn {started_id, tc_id, attempt} ->
      {tc_id, attempt, Map.fetch!(finishes, started_id)}
    end)
  end

  # The ordered step statuses per testCaseStarted id.
  defp step_statuses_by_started(envelopes) do
    envelopes
    |> Enum.filter(&Map.has_key?(&1, "testStepFinished"))
    |> Enum.reduce(%{order: [], by: %{}}, fn e, acc ->
      f = e["testStepFinished"]
      id = f["testCaseStartedId"]
      status = get_in(f, ["testStepResult", "status"])
      order = if id in acc.order, do: acc.order, else: acc.order ++ [id]
      %{order: order, by: Map.update(acc.by, id, [status], &(&1 ++ [status]))}
    end)
  end

  defp success?(envelopes) do
    env = Enum.find(envelopes, &Map.has_key?(&1, "testRunFinished"))
    get_in(env, ["testRunFinished", "success"])
  end

  # The single testCase's id (these tests all run one scenario).
  defp test_case_id(envelopes) do
    env = Enum.find(envelopes, &Map.has_key?(&1, "testCase"))
    env["testCase"]["id"]
  end

  # A step that raises until the `counter` agent has been bumped to `pass_on`, then passes.
  defp passes_on_attempt(counter, pass_on) do
    fn ->
      n = Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)
      if n < pass_on, do: raise("Exception in step"), else: :ok
    end
  end

  defp feature(step_text) do
    """
    Feature: F
      Scenario: S
        Given #{step_text}
    """
  end

  describe ":retry option (default off)" do
    test "without :retry, a failing case runs exactly once and is not retried" do
      registry = StepRegistry.new() |> StepRegistry.add("a step", fn -> raise "boom" end)

      envelopes = Messages.run(feature("a step"), registry)

      assert attempts(envelopes) == [{test_case_id(envelopes), 0, false}]
      assert success?(envelopes) == false
    end

    test "a passing case is never retried even with :retry set" do
      registry = StepRegistry.new() |> StepRegistry.add("a step", fn -> :ok end)

      envelopes = Messages.run(feature("a step"), registry, retry: 2)

      assert attempts(envelopes) == [{test_case_id(envelopes), 0, false}]
      assert success?(envelopes) == true
    end
  end

  describe "FAILED triggers a retry within the limit" do
    test "passes on the second attempt: attempt 0 (retried), attempt 1 (final)" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)
      registry = StepRegistry.new() |> StepRegistry.add("a step", passes_on_attempt(counter, 2))

      envelopes = Messages.run(feature("a step"), registry, retry: 2)

      tc = test_case_id(envelopes)
      assert attempts(envelopes) == [{tc, 0, true}, {tc, 1, false}]
      assert success?(envelopes) == true

      %{order: [a0, a1], by: by} = step_statuses_by_started(envelopes)
      assert by[a0] == ["FAILED"]
      assert by[a1] == ["PASSED"]
    end

    test "passes on the third attempt: two retried failures then a passing final attempt" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)
      registry = StepRegistry.new() |> StepRegistry.add("a step", passes_on_attempt(counter, 3))

      envelopes = Messages.run(feature("a step"), registry, retry: 2)

      tc = test_case_id(envelopes)
      assert attempts(envelopes) == [{tc, 0, true}, {tc, 1, true}, {tc, 2, false}]
      assert success?(envelopes) == true
    end

    test "exhausts the retry limit: all attempts fail, final willBeRetried is false, run fails" do
      registry = StepRegistry.new() |> StepRegistry.add("a step", fn -> raise "always" end)

      envelopes = Messages.run(feature("a step"), registry, retry: 2)

      tc = test_case_id(envelopes)
      assert attempts(envelopes) == [{tc, 0, true}, {tc, 1, true}, {tc, 2, false}]
      assert success?(envelopes) == false
    end
  end

  describe "non-FAILED statuses do not retry" do
    test "AMBIGUOUS runs exactly once even with :retry" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add(~r/^an ambiguous (.*?)$/, fn _ -> :ok end)
        |> StepRegistry.add(~r/^(.*?) step$/, fn _ -> :ok end)

      envelopes = Messages.run(feature("an ambiguous step"), registry, retry: 2)

      assert [{_tc, 0, false}] = attempts(envelopes)
      assert success?(envelopes) == false
    end

    test "PENDING runs exactly once even with :retry" do
      registry = StepRegistry.new() |> StepRegistry.add("a pending step", fn -> "pending" end)

      envelopes = Messages.run(feature("a pending step"), registry, retry: 2)

      assert [{_tc, 0, false}] = attempts(envelopes)
      assert success?(envelopes) == false
    end

    test "UNDEFINED runs exactly once even with :retry" do
      registry = StepRegistry.new()

      envelopes = Messages.run(feature("a non-existent step"), registry, retry: 2)

      assert [{_tc, 0, false}] = attempts(envelopes)
      assert success?(envelopes) == false
    end
  end

  describe "attachment isolation across attempts" do
    test "each attempt only carries the attachments produced during that attempt" do
      {:ok, counter} = Agent.start_link(fn -> 0 end)

      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn _args, _arg, world ->
          Attach.log(world, "attempt log")
          n = Agent.get_and_update(counter, fn n -> {n + 1, n + 1} end)
          if n < 2, do: raise("Exception in step"), else: :ok
        end)

      envelopes = Messages.run(feature("a step"), registry, retry: 2)

      # Two attempts; each emits exactly one attachment (the log), so two total — not
      # accumulating (which would yield 1 then 2).
      per_started =
        envelopes
        |> Enum.filter(&Map.has_key?(&1, "attachment"))
        |> Enum.group_by(fn e -> e["attachment"]["testCaseStartedId"] end)
        |> Enum.map(fn {_id, list} -> length(list) end)
        |> Enum.sort()

      assert per_started == [1, 1]
    end
  end
end
