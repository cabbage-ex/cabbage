defmodule Cabbage.FeaturesManager do
  alias Cabbage.{Config, Step}
  alias Gherkin.Elements.{Feature, Scenario, ScenarioOutline}

  def prepare_scenarios(%Feature{tags: tags, scenarios: scenarios}, options) do
    scenarios
    |> Enum.map(&populate_tags(&1, tags, options))
    |> Enum.flat_map(&prepare_single_scenario/1)
    |> Enum.with_index()
    |> Enum.map(&update_scenario_name/1)
  end

  defp populate_tags(%{tags: scenario_tags} = scenario, feature_tags, options) do
    %{scenario | tags: Config.tags(options, feature_tags ++ scenario_tags)}
  end

  defp prepare_single_scenario(%Scenario{} = scenario), do: [scenario]

  defp prepare_single_scenario(%ScenarioOutline{examples: examples, steps: steps} = scenario) do
    Enum.map(examples, &%{scenario | steps: preapre_steps_parameters(steps, &1)})
  end

  defp preapre_steps_parameters(steps, parameters), do: Enum.map(steps, &Step.with_parameters(&1, parameters))
  defp update_scenario_name({scenario, index}), do: %{scenario | name: "#{index}. #{scenario.name}"}
end
