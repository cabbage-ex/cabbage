defmodule Cabbage.Feature.ParameterType do
  @moduledoc false
  # Function to provide the regular expression that maps to a type used in a Cucumber expression.
  # For instance, in the cucumber expression `Given I have {count:int} rows`, the parameter
  # `count` is of type `int`.

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
