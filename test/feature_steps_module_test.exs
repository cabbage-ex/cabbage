Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureStepsModuleTest do
  use ExUnit.Case

  test "a feature can import steps from a Cabbage.Steps module and use a local step" do
    defmodule ImportingFeature do
      use Cabbage.Feature, file: "simple.feature", import: [Cabbage.SharedSteps]

      setup do
        {:ok, %{count: 0}}
      end

      # Local step; the Given/And/When are satisfied by the imported module.
      defthen ~r/^I provide Then$/, _vars, %{count: count} do
        assert count == 3
        :ok
      end
    end

    {result, output} = CabbageTestHelper.run([], [ImportingFeature])

    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
  end

  test "a local step wins over an imported same-pattern step (local first-match-wins)" do
    defmodule OverridingFeature do
      use Cabbage.Feature, file: "simple.feature", import: [Cabbage.SharedSteps]

      setup do
        {:ok, %{count: 0}}
      end

      # Same pattern as the imported "I provide When"; local must win, adding 10 not 1.
      defstep ~r/^I provide When$/, %{count: count} do
        {:ok, %{count: count + 10}}
      end

      # Given (+1) + And (+1) imported, When (+10) local => 12.
      defthen ~r/^I provide Then$/, _vars, %{count: count} do
        assert count == 12
        :ok
      end
    end

    {result, output} = CabbageTestHelper.run([], [OverridingFeature])

    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
  end

  test "a Cabbage.Steps module is not an ExUnit case and defines no tests" do
    {:module, _} = Code.ensure_loaded(Cabbage.SharedSteps)

    # An ExUnit case exposes __ex_unit__/0; a pure step library must not — it
    # generates no tests and never `use ExUnit.Case`.
    refute function_exported?(Cabbage.SharedSteps, :__ex_unit__, 0)

    # It is still a valid import source.
    assert function_exported?(Cabbage.SharedSteps, :raw_steps, 0)
    assert length(Cabbage.SharedSteps.raw_steps()) == 3
  end
end
