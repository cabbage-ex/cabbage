defmodule Cabbage.CallbacksExecutor do
  alias Cabbage.MissingStepError

  def execute_tests_callbacks(steps, state, implemented_steps) when is_list(steps) do
    Enum.reduce(steps, state, &execute_tests_callbacks(&1, &2, implemented_steps))
  end

  def execute_tests_callbacks(step, state, implemented_steps) do
    execute_first_matching_callback(step, state, implemented_steps)
    |> case do
      {:error, :no_match} -> raise MissingStepError, step: step
      response -> response
    end
  end

  def execute_setups_callbacks(setups, state, implemented_setups) when is_list(setups) do
    Enum.reduce(setups, state, &execute_setups_callbacks(&1, &2, implemented_setups))
  end

  def execute_setups_callbacks(setup, state, implemented_setups) do
    execute_first_matching_callback(setup, state, implemented_setups)
    |> case do
      {:error, :no_match} -> state
      response -> response
    end
  end

  defp execute_first_matching_callback(_context, _state, []), do: {:error, :no_match}

  defp execute_first_matching_callback(context, state, [callback | rest]) do
    case callback.(context, state) do
      {:error, :no_match} -> execute_first_matching_callback(context, state, rest)
      {:ok, response} -> Map.merge(state, response)
      _ -> state
    end
  end
end
