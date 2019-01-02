defmodule Cabbage.Step do
  alias Gherkin.Elements.Steps.{Given, When, Then}

  defstruct doc_string: "", line: 0, parameters: %{}, table_data: [], text: "", type: nil

  def from(%Given{} = step), do: from(step, :given)
  def from(%When{} = step), do: from(step, :when)
  def from(%Then{} = step), do: from(step, :then)
  def from(step, type), do: __MODULE__ |> struct(Map.from_struct(step)) |> Map.put(:type, type)

  def with_parameters(%__MODULE__{text: text} = step, parameters) do
    keys =
      parameters
      |> Map.keys()
      |> Enum.filter(&String.contains?(text, "<#{&1}>"))

    %{step | parameters: Map.take(parameters, keys)}
  end
end
