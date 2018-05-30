defmodule Cabbage.Feature.CucumberExpression do
  @moduledoc """
  Module which provides functionality to turn cucumber expression into valid regular expressions.
  In your step definition you can use Cucumber Expressions as follows:
  Supported types are `int`, `float`, `word`, `string`.
  """

  alias Cabbage.Feature.ParameterType

  @spec to_regex(String.t) :: Regex.t
  def to_regex(expression) do
    updated_expression =
      expression
      |> String.split
      |> Enum.reduce("", &replace/2)
      |> String.trim

    ~r/^#{updated_expression}$/
  end

  defp replace(token, acc) do
    token
    |> String.split(":")
    |> do_replace(acc)
  end

  defp do_replace(["{" <> capture_name, type], acc) do
    param_type =
      type
      |> String.trim_trailing("}")
      |> find_param_type

    updated_expression = Regex.replace(~r/{capture_name}/, param_type.regex, capture_name)
    "#{acc} #{updated_expression}"
  end

  defp do_replace(token, acc) do
    "#{acc} #{token}"
  end

  defp find_param_type(type) do
    ParameterType.get_parameter_types()
    |> Enum.find(fn(param_type) -> param_type.name == type end)
  end
end
