defmodule Cabbage.Feature.Parameter do
  @moduledoc false
  # Functions for extracting parameters out of a cucumber expressions and converting
  # those to regular expressions. A parameter is in the form of "{capture_name:type}".
  # The supported types are defined in `ParameterType`.

  defstruct [:type_regex, :capture_name]

  alias Cabbage.Feature.ParameterType

  @type t :: %__MODULE__{}

  @spec convert(String.t()) :: t() | String.t
  def convert(term) do
    parameter_format = ~r/\{(?<name>.*):(?<type>.*)\}/u

    case Regex.named_captures(parameter_format, term) do
      %{"name" => capture_name, "type" => type} ->
        regex = ParameterType.regex_for(type)
        struct(__MODULE__, type_regex: regex, capture_name: capture_name)

      _ ->
        term
    end
  end

  @spec to_regex(t()) :: Regex.t()
  def to_regex(parameter) do
    ~r/(?<#{parameter.capture_name}>#{Regex.source(parameter.type_regex)})/
  end
end
