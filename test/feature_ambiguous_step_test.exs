Code.require_file("test_helper.exs", __DIR__)

# Coverage for ambiguity (cabbage-ex/cabbage#88) in the compile-time `Cabbage.Feature`
# runner.
#
# `Cabbage.Feature` matches a scenario step against registered step definitions with silent
# first-match-wins (`find_implementation_of_step/2` over the `@steps` attribute). Because
# `@steps` accumulates by prepending, "first match" is the LAST textually-written matching
# `defgiven`/`defwhen`/`defthen` — a general pattern followed by a specific override lets the
# override win. Some feature modules rely on this, so the DEFAULT (`:ignore`) is preserved:
# one definition runs and no warning/raise is produced.
#
# `use Cabbage.Feature, on_ambiguous_step: :warn | :raise` opts in to surfacing the cases
# where more than one registered pattern matches a step. The default changes nothing.
defmodule Cabbage.FeatureAmbiguousStepTest do
  use ExUnit.Case

  import ExUnit.CaptureIO

  defp safe_unregister(name) do
    Process.unregister(name)
  rescue
    ArgumentError -> :ok
  end

  describe "default (on_ambiguous_step: :ignore)" do
    test "characterization: the LAST textually-written matching definition wins, silently" do
      Process.register(self(), :ambiguous_step_observer)
      on_exit(fn -> safe_unregister(:ambiguous_step_observer) end)

      # Defined lazily so the generated scenario only runs under CabbageTestHelper.run (when
      # the observer is registered), not as part of the outer suite. Both patterns match
      # "I have an ambiguous step"; each reports which one ran by sending to the registered
      # observer, since the step body runs in the ExUnit runner process.
      output =
        capture_io(:stderr, fn ->
          Code.eval_string("""
          defmodule FirstMatchWinsFeature do
            use Cabbage.Feature, file: "ambiguous.feature"

            defgiven ~r/^I have an (.+) step$/, _vars, _state do
              send(:ambiguous_step_observer, :general_pattern_ran)
              :ok
            end

            defgiven ~r/^I have an ambiguous (.+)$/, _vars, _state do
              send(:ambiguous_step_observer, :specific_pattern_ran)
              :ok
            end
          end
          """)
        end)

      {result, run_output} = CabbageTestHelper.run([], [:"Elixir.FirstMatchWinsFeature"])
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, run_output

      # `@steps` accumulates by prepending, so the last-written `defgiven` is found first.
      assert_received :specific_pattern_ran
      refute_received :general_pattern_ran

      # And it is silent at compile time under the default: no ambiguity warning.
      refute output =~ "Ambiguous step"
    end
  end

  describe "on_ambiguous_step: :warn" do
    test "emits a compile warning naming the ambiguous step and still compiles" do
      output =
        capture_io(:stderr, fn ->
          Code.eval_string("""
          defmodule WarnAmbiguousFeature do
            use Cabbage.Feature, file: "ambiguous.feature", on_ambiguous_step: :warn

            defgiven ~r/^I have an (.+) step$/, _vars, _state do
              :ok
            end

            defgiven ~r/^I have an ambiguous (.+)$/, _vars, _state do
              :ok
            end
          end
          """)
        end)

      assert output =~ "Ambiguous step"
      assert output =~ "I have an ambiguous step"

      # `:warn` does not change runtime behaviour: the module still compiled and runs.
      {result, run_output} = CabbageTestHelper.run([], [:"Elixir.WarnAmbiguousFeature"])
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, run_output
    end
  end

  describe "on_ambiguous_step: :raise" do
    test "aborts compilation with a CompileError naming the ambiguous step" do
      assert_raise CompileError, ~r/Ambiguous step/, fn ->
        Code.eval_string("""
        defmodule RaiseAmbiguousFeature do
          use Cabbage.Feature, file: "ambiguous.feature", on_ambiguous_step: :raise

          defgiven ~r/^I have an (.+) step$/, _vars, _state do
            :ok
          end

          defgiven ~r/^I have an ambiguous (.+)$/, _vars, _state do
            :ok
          end
        end
        """)
      end
    end
  end

  describe "invalid on_ambiguous_step value" do
    test "raises ArgumentError at use time" do
      assert_raise ArgumentError, ~r/invalid :on_ambiguous_step/, fn ->
        Code.eval_string("""
        defmodule BogusAmbiguousFeature do
          use Cabbage.Feature, file: "ambiguous.feature", on_ambiguous_step: :boom
        end
        """)
      end
    end
  end
end
