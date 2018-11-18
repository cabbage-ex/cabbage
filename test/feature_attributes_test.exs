Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureAttributesTest do
  @moduledoc """
  TODO: Is this test even necessary?
  It seems to test Gherkin library, not this one.
  Inspired by Cabbage.FeatureTest
  """
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "Feature has correct attributes" do
    test "simple feature contains correct attributes" do
      defmodule FeatureAttributeTest do
        use Cabbage.Feature, file: "simplest.feature"
        alias Gherkin.Elements.Scenario

        test "has a @feature" do
          # [:background_steps, :description, :file, :line, :name, :role, :scenarios, :tags]
          assert "Placeholder feature" == @feature.name
          assert [%Scenario{} = scenario] = @feature.scenarios
          assert "Placeholder scenario" == scenario.name
          assert 1 == length(scenario.steps)
        end

        defthen ~r/^I provide Then$/, _vars, _state do
        end
      end

      ExUnit.Server.modules_loaded()
      capture_io(fn -> assert ExUnit.run() == %{failures: 0, skipped: 0, total: 2, excluded: 0} end)
    end

    test "outlined feature contains correct attributes" do
      defmodule FeatureAttributeTest2 do
        use Cabbage.Feature, file: "outline.feature"
        alias Gherkin.Elements.Scenario

        test "has a @feature" do
          # [:background_steps, :description, :file, :line, :name, :role, :scenarios, :tags]
          assert "Provide outline" == @feature.name

          assert [
                   %Scenario{} = scenario1,
                   %Scenario{} = scenario2,
                   %Scenario{} = scenario3,
                   %Scenario{} = scenario4,
                   %Scenario{} = scenario5,
                   %Scenario{} = scenario6
                 ] = @feature.scenarios

          assert "Outlined scenario (Example 1)" == scenario1.name
          assert 3 == length(scenario1.steps)

          assert "Outlined scenario (Example 2)" == scenario2.name
          assert 3 == length(scenario2.steps)

          assert "Outlined scenario (Example 3)" == scenario3.name
          assert 3 == length(scenario3.steps)

          assert "Outlined scenario with numbers (Example 1)" == scenario4.name
          assert 3 == length(scenario4.steps)

          assert "Outlined scenario with numbers (Example 2)" == scenario5.name
          assert 3 == length(scenario5.steps)

          assert "Outlined scenario with numbers (Example 3)" == scenario6.name
          assert 3 == length(scenario6.steps)
        end

        defgiven ~r/^there is given (?<string_1>[^\" ]+) value$/, _vars, _state do
        end

        defgiven ~r/^there is given numeric (?<number_1>\d+) value$/, _vars, _state do
        end

        defwhen ~r/^there is when (?<string_1>[^\" ]+) value$/, _vars, _state do
        end

        defwhen ~r/^there is when numeric (?<number_1>\d+) value$/, _vars, _state do
        end

        defthen ~r/^there is then (?<string_1>[^\" ]+) value$/, _vars, _state do
        end

        defthen ~r/^there is then numeric (?<number_1>\d+) value$/, _vars, _state do
        end
      end

      ExUnit.Server.modules_loaded()
      capture_io(fn -> assert ExUnit.run() == %{failures: 0, skipped: 0, total: 7, excluded: 0} end)
    end
  end
end
