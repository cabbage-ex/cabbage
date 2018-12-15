defmodule Cabbage.StepsManager do
  alias Gherkin.Elements.Steps

  def handles_step?({:given, regex}, %Steps.Given{text: text}), do: Regex.match?(regex, text)
  def handles_step?({:when, regex}, %Steps.When{text: text}), do: Regex.match?(regex, text)
  def handles_step?({:then, regex}, %Steps.Then{text: text}), do: Regex.match?(regex, text)
  def handles_step?(_, _), do: false

  def extract_parameters(regex, %{text: text, table_data: table, doc_string: doc_string}) do
    regex
    |> Regex.named_captures(text)
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Enum.into(%{})
    |> Map.put(:table, table)
    |> Map.put(:doc_string, doc_string)
  end
end
