defmodule Cabbage.Feature.ParameterType do
  @moduledoc """
  Function to provide the regular expression for a type used in a Cucumber expression.
  """

  @spec regex_for(String.t()) :: Regex.t()
  def regex_for(type) do
    Map.get(parameter_types(), type)
  end

  defp parameter_types do
    %{
      "int" => ~r/\d+/,
      "float" => ~r/\d+\.\d+/,
      "word" => ~r/\w*\S/,
      "string" => ~r/"(.*)"/
    }
  end
end
