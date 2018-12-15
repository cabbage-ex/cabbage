defmodule Cabbage.Feature.TestRunner do
  alias Gherkin.Elements.Scenario
  alias Cabbage.Feature.{ImplementedStep, StepsManager}

  def run_scenario(%Scenario{} = scenario, implemented_steps, test_state) do
    scenario.steps
    |> Enum.reduce(test_state, &execute_scenario_step(&1, &2, implemented_steps))
  end

  defp execute_scenario_step(step, test_state, []), do: throw(:no_match)

  defp execute_scenario_step(step, test_state, [implementation | rest]) do
    case implementation.(step, test_state) do
      {:error, :no_match} -> execute_scenario_step(step, test_state, rest)
      {:ok, response} -> Map.merge(test_state, response)
      _ -> test_state
    end
  end
end
