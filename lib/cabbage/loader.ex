defmodule Cabbage.Loader do
  @moduledoc """
  Can load and parse feature files and raw strings.
  """

  alias Gherkin.Elements.{Feature, Scenario, ScenarioOutline}
  alias Gherkin.Elements.Steps.{And, But}
  alias Cabbage.Step

  @doc """
  Loads and parses feature from file
  """
  def load_from_file(path) do
    path
    |> Gherkin.parse_file()
    |> integrate_background_steps()
    |> fix_step_types()
  end

  defp integrate_background_steps(%Feature{background_steps: backgroud, scenarios: scenarios} = feature) do
    %{feature | scenarios: Enum.map(scenarios, &integrate_background_steps(&1, backgroud))}
  end

  defp integrate_background_steps(%scenario_type{steps: steps} = scenario, backgroud_steps)
       when scenario_type in [Scenario, ScenarioOutline] do
    %{scenario | steps: backgroud_steps ++ steps}
  end

  defp fix_step_types(%Feature{scenarios: scenarios} = feature) do
    scenarios = scenarios |> Enum.map(&fix_step_types/1)
    %{feature | scenarios: scenarios}
  end

  defp fix_step_types(%scenario_type{steps: steps} = scenario) when scenario_type in [Scenario, ScenarioOutline] do
    steps = steps |> Enum.reduce([], &fix_step_type/2) |> Enum.reverse()
    %{scenario | steps: steps}
  end

  defp fix_step_type(%And{} = current_step, [%{type: type} | _] = steps), do: [Step.from(current_step, type) | steps]
  defp fix_step_type(%But{} = current_step, [%{type: type} | _] = steps), do: [Step.from(current_step, type) | steps]
  defp fix_step_type(current_step, steps), do: [Step.from(current_step) | steps]
end
