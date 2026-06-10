Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureStateThreadingTest do
  use ExUnit.Case

  describe "value-threaded scenario state" do
    test "does not leak a per-scenario Agent process (state is threaded, not held in a process)" do
      defmodule StateThreadingLeakTest do
        use Cabbage.Feature, file: "simple.feature"

        defgiven ~r/^I provide Given$/, _vars, _state do
          {:ok, %{given: true}}
        end

        defgiven ~r/^I provide And$/, _vars, %{given: given} do
          assert given
          :ok
        end

        defwhen ~r/^I provide When$/, _vars, _state do
          :ok
        end

        defthen ~r/^I provide Then$/, _vars, _state do
          assert true
          :ok
        end
      end

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}

      leaked =
        Process.registered()
        |> Enum.filter(&String.starts_with?(Atom.to_string(&1), "cabbage_integration_test"))

      assert leaked == [],
             "expected no lingering cabbage state processes, found: #{inspect(leaked)}"
    end

    test "threads state across Given/And/When/Then under async: true" do
      defmodule AsyncStateThreadingTest do
        use Cabbage.Feature, file: "simple.feature", async: true

        defgiven ~r/^I provide Given$/, _vars, state do
          {:ok, %{steps: [:given | Map.get(state, :steps, [])]}}
        end

        defgiven ~r/^I provide And$/, _vars, state do
          {:ok, %{steps: [:and | state.steps]}}
        end

        defwhen ~r/^I provide When$/, _vars, state do
          {:ok, %{steps: [:when | state.steps]}}
        end

        defthen ~r/^I provide Then$/, _vars, state do
          assert Enum.reverse(state.steps) == [:given, :and, :when]
          :ok
        end
      end

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end

    test "tag-contributed state seeds the initial context" do
      defmodule TagSeededStateTest do
        use Cabbage.Feature, file: "simplest.feature"
        @moduletag :seed_tag

        tag @seed_tag do
          {:ok, %{seeded: :yes}}
        end

        defthen ~r/^I provide Then$/, _vars, state do
          assert state.seeded == :yes
          :ok
        end
      end

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end
  end
end
