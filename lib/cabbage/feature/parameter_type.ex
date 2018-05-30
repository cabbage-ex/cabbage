defmodule Cabbage.Feature.ParameterType do
  defstruct [:name, :regex]

  def get_parameter_types do
    [
      %__MODULE__{name: "int", regex: "(?<{capture_name}>\\d+)"},
      %__MODULE__{name: "float", regex: "(?<{capture_name}>\\d+\\.\\d+)"},
      %__MODULE__{name: "word", regex: "(?<{capture_name}>\\w*\\S)"},
      %__MODULE__{name: "string", regex: "(?<{capture_name}>\"(.*)\")"}
    ]
  end
end
