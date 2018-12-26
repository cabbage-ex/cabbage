defmodule Cabbage.Loader do
  @moduledoc """
  Can load and parse feature files and raw strings.
  """

  alias Gherkin.Elements.{Feature, Scenario, Steps}

  @doc """
  Loads and parses feature from file
  """
  def load_from_file(path) do
    path
    |> File.read!()
    |> load_from_string()
  end

  @doc """
  Loads and parses feature from string
  """
  def load_from_string(string) do
    string
    |> Gherkin.parse()
    |> Gherkin.flatten()
    |> integrate_background_steps()
    |> fix_step_types()
  end

  defp integrate_background_steps(%Feature{background_steps: backgroud, scenarios: scenarios} = feature) do
    %{feature | scenarios: Enum.map(scenarios, &integrate_background_steps(&1, backgroud))}
  end

  defp integrate_background_steps(%Scenario{steps: steps} = scenario, backgroud_steps) do
    %{scenario | steps: backgroud_steps ++ steps}
  end

  defp fix_step_types(%Feature{scenarios: scenarios} = feature) do
    scenarios = scenarios |> Enum.map(&fix_step_types/1)
    %{feature | scenarios: scenarios}
  end

  defp fix_step_types(%Scenario{steps: steps} = scenario) do
    steps = steps |> Enum.reduce([], &fix_step_type/2) |> Enum.reverse()
    %{scenario | steps: steps}
  end

  defp fix_step_type(%Steps.And{} = current_step, [previous_step | _] = steps) do
    fixed_step = %{current_step | __struct__: previous_step.__struct__}
    [fixed_step | steps]
  end

  defp fix_step_type(current_step, steps), do: [current_step | steps]
end
