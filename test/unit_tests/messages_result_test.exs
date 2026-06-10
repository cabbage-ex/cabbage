defmodule Cabbage.MessagesResultTest do
  @moduledoc """
  Behavioural tests for the result/exception state machine of the message-emitting
  runner (`Cabbage.Messages.run/3`).

  These pin the cucumber-messages semantics the CCK status/exception areas require:

    * each step status (PASSED/FAILED/UNDEFINED/AMBIGUOUS/PENDING/SKIPPED);
    * pending/skipped *via a returned value* carry NO `exception`;
    * pending/skipped *via a raised exception* carry an `exception` with the
      reference `PendingException`/`SkippedException` type;
    * the skip-propagation rule from cucumber-js (and the CCK
      `failedish-combinations` sample): a step is reported SKIPPED only when a
      prior step intrinsically SKIPPED, or when a prior step was failed-ish *and*
      this step is executable (single match). UNDEFINED/AMBIGUOUS steps keep
      their intrinsic status after a failed-ish step but not after a real skip.
  """
  use ExUnit.Case, async: true

  alias Cabbage.Messages
  alias Cabbage.Messages.StepRegistry

  # The ordered list of step statuses across the run (one per testStepFinished),
  # each tagged with its exception type when present.
  defp statuses(envelopes) do
    envelopes
    |> Enum.filter(&Map.has_key?(&1, "testStepFinished"))
    |> Enum.map(fn env ->
      result = get_in(env, ["testStepFinished", "testStepResult"])

      case result["exception"] do
        nil -> result["status"]
        %{"type" => type} -> {result["status"], type}
      end
    end)
  end

  defp success?(envelopes) do
    env = Enum.find(envelopes, &Map.has_key?(&1, "testRunFinished"))
    get_in(env, ["testRunFinished", "success"])
  end

  describe "individual step statuses" do
    test "a returned :ok / nil passes" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn -> :ok end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      assert statuses(Messages.run(feature, registry)) == ["PASSED"]
      assert success?(Messages.run(feature, registry)) == true
    end

    test "a raised error fails with exception type Error and no AssertionError" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn -> raise "whoops" end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      envelopes = Messages.run(feature, registry)
      assert statuses(envelopes) == [{"FAILED", "Error"}]
      assert success?(envelopes) == false
    end

    test "a failed pattern match reports AssertionError" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn -> :ok = Enum.random([:not_ok]) end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      assert statuses(Messages.run(feature, registry)) == [{"FAILED", "AssertionError"}]
    end

    test "returning \"pending\" yields PENDING with no exception" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn -> "pending" end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      envelopes = Messages.run(feature, registry)
      assert statuses(envelopes) == ["PENDING"]
      assert success?(envelopes) == false
    end

    test "returning \"skipped\" yields SKIPPED with no exception and a successful run" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn -> "skipped" end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      envelopes = Messages.run(feature, registry)
      assert statuses(envelopes) == ["SKIPPED"]
      assert success?(envelopes) == true
    end

    test "raising Cabbage.PendingError yields PENDING with PendingException type" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn -> raise Cabbage.PendingError, "TODO" end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      envelopes = Messages.run(feature, registry)
      assert statuses(envelopes) == [{"PENDING", "PendingException"}]
      assert success?(envelopes) == false
    end

    test "raising Cabbage.SkippedError yields SKIPPED with SkippedException type and success" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("a step", fn -> raise Cabbage.SkippedError, "later" end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      envelopes = Messages.run(feature, registry)
      assert statuses(envelopes) == [{"SKIPPED", "SkippedException"}]
      assert success?(envelopes) == true
    end
  end

  describe "skip-propagation rule (failedish-combinations semantics)" do
    # A registry mirroring the CCK failedish/all-statuses step defs.
    defp failedish_registry do
      StepRegistry.new()
      |> StepRegistry.add("a step", fn -> :ok end)
      |> StepRegistry.add("a failing step", fn -> raise "whoops" end)
      |> StepRegistry.add("a pending step", fn -> "pending" end)
      |> StepRegistry.add("a skipped step", fn -> "skipped" end)
      |> StepRegistry.add(~r/^an ambiguous (.*?)$/, fn _ -> :ok end)
      |> StepRegistry.add(~r/^(.*?) ambiguous step$/, fn _ -> :ok end)
    end

    defp run_scenario(step_lines) do
      steps = Enum.map_join(step_lines, "\n", &"    Given #{&1}")

      feature = """
      Feature: F
        Scenario: S
      #{steps}
      """

      failedish_registry() |> then(&Messages.run(feature, &1)) |> statuses()
    end

    test "pending does not skip following undefined/ambiguous steps" do
      assert run_scenario(["a pending step", "an undefined step", "an ambiguous step"]) ==
               ["PENDING", "UNDEFINED", "AMBIGUOUS"]
    end

    test "failed does not skip following undefined/ambiguous, but skips executable steps" do
      assert run_scenario(["a failing step", "an undefined step", "an ambiguous step"]) ==
               [{"FAILED", "Error"}, "UNDEFINED", "AMBIGUOUS"]
    end

    test "an executable step after a failed-ish step is SKIPPED" do
      assert run_scenario(["a pending step", "a pending step", "a failing step"]) ==
               ["PENDING", "SKIPPED", "SKIPPED"]
    end

    test "an intrinsic skip cascades to ALL following steps, even undefined/ambiguous" do
      assert run_scenario(["a skipped step", "an undefined step", "an ambiguous step"]) ==
               ["SKIPPED", "SKIPPED", "SKIPPED"]
    end

    test "undefined first then ambiguous keeps both intrinsic statuses" do
      assert run_scenario(["an undefined step", "an undefined step", "an ambiguous step"]) ==
               ["UNDEFINED", "UNDEFINED", "AMBIGUOUS"]
    end

    test "ambiguous first then executable pending then executable failing" do
      assert run_scenario(["an ambiguous step", "a pending step", "a failing step"]) ==
               ["AMBIGUOUS", "SKIPPED", "SKIPPED"]
    end
  end

  describe "run/3 option validation" do
    setup do
      registry = StepRegistry.new() |> StepRegistry.add("a step", fn -> :ok end)

      feature = """
      Feature: F
        Scenario: S
          Given a step
      """

      %{registry: registry, feature: feature}
    end

    test "accepts the per-feature options :uri and :format", %{
      registry: registry,
      feature: feature
    } do
      assert statuses(Messages.run(feature, registry, uri: "f.feature", format: :plain)) ==
               ["PASSED"]
    end

    test "raises on :order (a run-wide option that run/3 cannot honour)", %{
      registry: registry,
      feature: feature
    } do
      assert_raise ArgumentError, ~r/unknown option.*:order.*run_features\/2/s, fn ->
        Messages.run(feature, registry, order: :reverse)
      end
    end

    test "raises on any other unknown option", %{registry: registry, feature: feature} do
      assert_raise ArgumentError, ~r/unknown option.*:bogus/, fn ->
        Messages.run(feature, registry, bogus: true)
      end
    end
  end
end
