defmodule Cabbage.Feature.CucumberExpression do
  @moduledoc false
  # Module which provides functionality to turn cucumber expression into valid regular expressions.
  # In your step definition you can use Cucumber Expressions as follows:
  # Supported types are `int`, `float`, `word`, `string`.

  alias Cabbage.Feature.Parameter

  @spec to_regex_string(String.t()) :: String.t()
  def to_regex_string(expression) do
    expression
    |> split_into_terms
    |> determine_parameters
    |> convert_parameters_to_regex_patterns
    |> stringify
  end

  defp split_into_terms(expression) do
    String.split(expression)
  end

  defp determine_parameters(terms) do
    Enum.map(terms, &Parameter.convert/1)
  end

  defp convert_parameters_to_regex_patterns(term_or_parameters) do
    Enum.map(term_or_parameters, fn
      %Parameter{} = parameter -> Parameter.to_regex(parameter)
      term -> term
    end)
  end

  defp stringify(term_or_regex_patterns) do
    expression =
      term_or_regex_patterns
      |> Enum.map(&stringify_term_or_regex_pattern/1)
      |> Enum.join(" ")

    "^" <> expression <> "$"
  end

  defp stringify_term_or_regex_pattern(%Regex{} = regex), do: Regex.source(regex)
  defp stringify_term_or_regex_pattern(term) when is_binary(term), do: term
end
