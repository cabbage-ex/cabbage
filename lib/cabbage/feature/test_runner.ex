defmodule Cabbage.Feature.TestRunner do
  alias Gherkin.Elements.Scenario
  alias Cabbage.Feature.{ImplementedStep, StepsManager}

  def run_scenario(%Scenario{} = scenario, implemented_steps, test_state) do
    scenario.steps
    |> Enum.reduce(test_state, &execute_scenario_step(&1, &2, implemented_steps))
  end

  defp execute_scenario_step(step, test_state, []), do: throw(:no_match)

  defp execute_scenario_step(step, test_state, [implementation | rest]) do
    with true <- ImplementedStep.handles_step?(implementation, step),
         parameters <- ImplementedStep.extract_parameters(implementation, step),
         {:ok, response} <- execute_implemented_step(implementation, parameters, test_state) do
      Map.merge(test_state, response)
    else
      _ ->
        execute_scenario_step(step, test_state, rest)
    end
  end

  defp execute_implemented_step(%ImplementedStep{} = implementation, parameters, test_state) do
    %{parameters: parameters_pattern, state: state_pattern, block: block} = implementation

    quote generated: true do
      with unquote(parameters_pattern) <- unquote(Macro.escape(parameters)),
           unquote(state_pattern) <- unquote(Macro.escape(test_state)) do
        unquote(block)
      else
        _ -> :no_match
      end
    end
    |> Code.eval_quoted()
    |> elem(0)
    |> case do
      :no_match -> {:error, :no_match}
      {:ok, response} when is_map(response) -> {:ok, response}
      _ -> {:ok, %{}}
    end
  end
end
