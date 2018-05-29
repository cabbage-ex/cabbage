defmodule Cabbage.Feature.CucumberExpressions do

  @spec implemented?(step_text :: String.t, Tuple.t) :: boolean
  def implemented?(step_text, {:{}, _, [expression, _, _, _, _]}) when is_binary(expression) do
    step_text =~ expression
  end

  def implemented?(step_text, {:{}, _, [expression, _, _, _, _]}) do
    {regex, _} = Code.eval_quoted(expression)
    step_text =~ regex
  end

  @spec to_regex(String.t | Regex.t) :: Regex.t
  def to_regex(expression) when is_binary(expression) do
    Cabbage.Feature.CucumberExpression.prepare(expression)
  end

  def to_regex(expression) do
    {regex, _} = Code.eval_quoted(expression)
    regex
  end
end
