defmodule Cabbage.Executor do
  @moduledoc """
  Executes first matching registered callbacks.
  """

  @doc """
  Execute callbacks till first match is found or returns error `{:error, :no_match}`
  """
  def execute_first_matching_callback(_context, _state, []), do: {:error, :no_match}

  def execute_first_matching_callback(context, state, [callback | rest]) do
    case callback.(context, state) do
      {:error, :no_match} -> execute_first_matching_callback(context, state, rest)
      {:ok, response} -> {:ok, Map.merge(state, response)}
      _ -> {:ok, state}
    end
  end
end
