defmodule Cabbage.SetupsManager do
  @moduledoc """
  Setups related helpers
  """

  alias Cabbage.Executor

  @doc """
  Executes first tag setup callback or returns unmodified state
  """
  def execute(setup, state, setups_callbacks) do
    case Executor.execute_first_matching_callback(setup, state, setups_callbacks) do
      {:error, :no_match} -> state
      {:ok, response} -> response
    end
  end

  @doc """
  Determines if callback tag matches test tag
  """
  def are_tags_equal?(callback_tag, executing_tag), do: callback_tag == executing_tag

  @doc """
  Normalizes tags for ExUnit test registering
  """
  def normalize_tags_for_test(tags) do
    Enum.map(tags, fn
      {tag, value} -> [{tag, value}]
      tag -> tag
    end)
  end
end
