defmodule Cabbage.Feature.Parameter do
  defstruct [:type_regex, :capture_name]

  alias Cabbage.Feature.ParameterType

  @type t :: %__MODULE__{}

  @spec extract(String.t()) :: t() | nil
  def extract(term) do
    parameter_format = ~r/\{(?<name>.*):(?<type>.*)\}/u

    case Regex.named_captures(parameter_format, term) do
      %{"name" => capture_name, "type" => type} ->
        regex = ParameterType.regex_for(type)
        struct(__MODULE__, type_regex: regex, capture_name: capture_name)

      _ ->
        nil
    end
  end

  @spec to_regex(t()) :: Regex.t()
  def to_regex(parameter) do
    ~r/(?<#{parameter.capture_name}>#{Regex.source(parameter.type_regex)})/
  end
end
