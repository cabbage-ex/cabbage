defmodule Cabbage.MessagesHooksTest do
  @moduledoc """
  Behavioural tests for the hook subsystem of the message-emitting runner
  (`Cabbage.Messages.run/3` with a `:hooks` registry).

  These pin the cucumber-messages semantics the CCK hook areas require:

    * scenario before/after hooks become `testStep`s with a `hookId` (no `pickleStepId`),
      wrapped in `testStepStarted`/`testStepFinished`, before/after the pickle steps;
    * `hook` definition envelopes are emitted in the registration section;
    * global BeforeAll/AfterAll hooks become `testRunHookStarted`/`testRunHookFinished`
      after `testRunStarted` / before `testRunFinished`, AfterAll in reverse order;
    * tag-scoped hooks only apply to matching pickles;
    * skip/fail propagation mirrors fake-cucumber (failing Before skips the steps but
      After still runs; a skipped Before cascades to later Befores and steps; a skipped
      After only marks itself; a failing hook fails the run).
  """
  use ExUnit.Case, async: true

  alias Cabbage.Messages
  alias Cabbage.Messages.{HookRegistry, StepRegistry}

  defp types(envelopes), do: Enum.map(envelopes, fn e -> e |> Map.keys() |> List.first() end)

  # statuses of every testStepFinished (scenario steps AND scenario-hook steps), in order
  defp step_statuses(envelopes) do
    envelopes
    |> Enum.filter(&Map.has_key?(&1, "testStepFinished"))
    |> Enum.map(&get_in(&1, ["testStepFinished", "testStepResult", "status"]))
  end

  defp run_hook_statuses(envelopes) do
    envelopes
    |> Enum.filter(&Map.has_key?(&1, "testRunHookFinished"))
    |> Enum.map(&get_in(&1, ["testRunHookFinished", "result", "status"]))
  end

  defp success?(envelopes) do
    env = Enum.find(envelopes, &Map.has_key?(&1, "testRunFinished"))
    get_in(env, ["testRunFinished", "success"])
  end

  defp registry(steps) do
    Enum.reduce(steps, StepRegistry.new(), fn {pat, fun}, r ->
      StepRegistry.add(r, pat, fun, uri: "x.ts", line: 1)
    end)
  end

  describe "scenario hooks" do
    test "before and after hook become hook defs + hookId test steps wrapping the pickle steps" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_case, fn -> :ok end, uri: "h.ts", line: 1)
        |> HookRegistry.add(:after_test_case, fn -> :ok end, uri: "h.ts", line: 5)

      envelopes = Messages.run(feature, steps, hooks: hooks)

      # two hook definition envelopes in the registration section
      assert Enum.count(envelopes, &Map.has_key?(&1, "hook")) == 2

      # testCase has three test steps: before-hook, pickle step, after-hook
      test_case = Enum.find(envelopes, &Map.has_key?(&1, "testCase"))
      test_steps = test_case["testCase"]["testSteps"]
      assert [%{"hookId" => _}, %{"pickleStepId" => _}, %{"hookId" => _}] = test_steps
      refute Map.has_key?(Enum.at(test_steps, 0), "pickleStepId")

      # three testStepStarted/Finished pairs, all PASSED
      assert step_statuses(envelopes) == ["PASSED", "PASSED", "PASSED"]
      assert success?(envelopes)
    end

    test "hook name and tag expression are carried into the hook envelope" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_case, fn -> :ok end, name: "A named before hook")

      envelopes = Messages.run(feature, steps, hooks: hooks)
      hook = Enum.find(envelopes, &Map.has_key?(&1, "hook"))
      assert hook["hook"]["name"] == "A named before hook"
      assert hook["hook"]["type"] == "BEFORE_TEST_CASE"
    end

    test "tag-scoped hook only applies to matching pickles" do
      feature =
        "Feature: f\n  @on\n  Scenario: a\n    When a step passes\n  Scenario: b\n    When a step passes\n"

      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_case, fn -> :ok end, tag: "@on")

      envelopes = Messages.run(feature, steps, hooks: hooks)

      # scenario a: hook + step (2 steps); scenario b: step only (1). total 3 finished.
      assert step_statuses(envelopes) == ["PASSED", "PASSED", "PASSED"]
    end

    test "a failing Before hook marks itself FAILED, skips the steps, but the After hook still runs" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_case, fn -> raise "boom" end)
        |> HookRegistry.add(:after_test_case, fn -> :ok end)

      envelopes = Messages.run(feature, steps, hooks: hooks)
      assert step_statuses(envelopes) == ["FAILED", "SKIPPED", "PASSED"]
      refute success?(envelopes)
    end

    test "a skipped Before hook cascades skip to later Before hooks and steps, After hooks run" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_case, fn -> "skipped" end)
        |> HookRegistry.add(:before_test_case, fn -> :ok end)
        |> HookRegistry.add(:after_test_case, fn -> :ok end)

      envelopes = Messages.run(feature, steps, hooks: hooks)
      # skipped Before, cascaded-skip Before, skipped step, passed After
      assert step_statuses(envelopes) == ["SKIPPED", "SKIPPED", "SKIPPED", "PASSED"]
      # a pure skip is still a successful run
      assert success?(envelopes)
    end

    test "a skipped After hook only marks itself; later After hooks still run" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:after_test_case, fn -> "skipped" end)
        |> HookRegistry.add(:after_test_case, fn -> :ok end)

      envelopes = Messages.run(feature, steps, hooks: hooks)
      assert step_statuses(envelopes) == ["PASSED", "SKIPPED", "PASSED"]
      assert success?(envelopes)
    end

    test "a failing After hook after a skipped step fails the run overall" do
      feature = "Feature: f\n  Scenario: s\n    Given a step that skips\n"
      steps = registry([{"a step that skips", fn -> "skipped" end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:after_test_case, fn -> raise "whoops" end)

      envelopes = Messages.run(feature, steps, hooks: hooks)
      assert step_statuses(envelopes) == ["SKIPPED", "FAILED"]
      refute success?(envelopes)
    end

    test "hooks still run around an undefined step" do
      feature = "Feature: f\n  Scenario: s\n    When a step does not exist\n"
      steps = registry([])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_case, fn -> :ok end)
        |> HookRegistry.add(:after_test_case, fn -> :ok end)

      envelopes = Messages.run(feature, steps, hooks: hooks)
      assert step_statuses(envelopes) == ["PASSED", "UNDEFINED", "PASSED"]
    end
  end

  describe "global hooks" do
    test "BeforeAll runs in order after testRunStarted, AfterAll in reverse before testRunFinished" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_run, fn -> :ok end)
        |> HookRegistry.add(:after_test_run, fn -> :ok end)

      envelopes = Messages.run(feature, steps, hooks: hooks)
      t = types(envelopes)

      run_started = Enum.find_index(t, &(&1 == "testRunStarted"))
      first_case = Enum.find_index(t, &(&1 == "testCaseStarted"))
      run_finished = Enum.find_index(t, &(&1 == "testRunFinished"))

      # BeforeAll hook pair sits between testRunStarted and the first testCaseStarted
      assert "testRunHookStarted" in Enum.slice(t, run_started..first_case)
      # AfterAll hook pair sits between the last testCaseFinished and testRunFinished
      assert "testRunHookStarted" in Enum.slice(t, first_case..run_finished)
      assert run_hook_statuses(envelopes) == ["PASSED", "PASSED"]
      assert success?(envelopes)
    end

    test "a BeforeAll error fails the run and skips test case execution; remaining hooks still run" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:before_test_run, fn -> :ok end)
        |> HookRegistry.add(:before_test_run, fn -> raise "BeforeAll went wrong" end)
        |> HookRegistry.add(:before_test_run, fn -> :ok end)
        |> HookRegistry.add(:after_test_run, fn -> :ok end)

      envelopes = Messages.run(feature, steps, hooks: hooks)

      # all 3 BeforeAll + 1 AfterAll ran
      assert run_hook_statuses(envelopes) == ["PASSED", "FAILED", "PASSED", "PASSED"]
      # no scenario was executed
      refute Enum.any?(envelopes, &Map.has_key?(&1, "testCaseStarted"))
      refute success?(envelopes)
    end

    test "an AfterAll error fails the run; test cases still execute" do
      feature = "Feature: f\n  Scenario: s\n    When a step passes\n"
      steps = registry([{"a step passes", fn -> :ok end}])

      hooks =
        HookRegistry.new()
        |> HookRegistry.add(:after_test_run, fn -> :ok end)
        |> HookRegistry.add(:after_test_run, fn -> raise "AfterAll went wrong" end)

      envelopes = Messages.run(feature, steps, hooks: hooks)
      assert Enum.any?(envelopes, &Map.has_key?(&1, "testCaseStarted"))
      # AfterAll emitted in reverse: the failing (2nd-registered) runs first
      assert run_hook_statuses(envelopes) == ["FAILED", "PASSED"]
      refute success?(envelopes)
    end
  end
end
