defmodule Cabbage.Feature.ImplementedStep do
  alias Gherkin.Elements.Steps

  defstruct [:type, :regex, :parameters, :state, :block]

  def from_raw(type, regex, parameters, state, block) do
    %__MODULE__{
      type: type,
      regex: regex,
      parameters: parameters,
      state: state,
      block: block
    }
  end

  def handles_step?(%__MODULE__{type: :given, regex: regex}, %Steps.Given{text: text}), do: Regex.match?(regex, text)
  def handles_step?(%__MODULE__{type: :when, regex: regex}, %Steps.When{text: text}), do: Regex.match?(regex, text)
  def handles_step?(%__MODULE__{type: :then, regex: regex}, %Steps.Then{text: text}), do: Regex.match?(regex, text)
  def handles_step?(%__MODULE__{}, _), do: false

  def extract_parameters(%__MODULE__{regex: regex}, %{text: text}) do
    regex
    |> Regex.named_captures(text)
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Enum.into(%{})
  end
end
