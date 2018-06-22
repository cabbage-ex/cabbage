defmodule Cabbage.Feature.CucumberExpression do
  @moduledoc """
  Module which provides functionality to turn cucumber expression into valid regular expressions.
  In your step definition you can use Cucumber Expressions as follows:
  Supported types are `int`, `float`, `word`, `string`.
  """

  alias Cabbage.Feature.{Parameter, ParameterType}

  @spec to_regex(String.t()) :: Regex.t()
  def to_regex(expression) do
    expression
    |> split_into_terms
    |> try_convert_terms_to_regex_patterns
    |> combine_terms_and_regex_patterns
  end

  defp split_into_terms(expression) do
    String.split(expression)
  end

  defp try_convert_terms_to_regex_patterns(terms) do
    Enum.map(terms, &try_convert_term_to_regex_pattern/1)
  end

  defp try_convert_term_to_regex_pattern(term) do
    case Parameter.extract(term) do
      nil -> term
      parameter -> Parameter.to_regex(parameter)
    end
  end

  defp combine_terms_and_regex_patterns(term_or_regex_patterns) do
    expression =
      term_or_regex_patterns
      |> Enum.map(&stringify_term_or_regex_pattern/1)
      |> Enum.join(" ")

    ~r/^#{expression}$/
  end

  defp stringify_term_or_regex_pattern(%Regex{} = regex), do: Regex.source(regex)
  defp stringify_term_or_regex_pattern(term), do: term
end
