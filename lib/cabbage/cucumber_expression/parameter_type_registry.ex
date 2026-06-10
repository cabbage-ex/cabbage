defmodule Cabbage.CucumberExpression.ParameterTypeRegistry do
  @moduledoc """
  Registry of parameter types, seeded with the built-in Cucumber Expression
  types. Custom types can be added with `define/2`.

  Ported from cucumber/cucumber-expressions (`ParameterTypeRegistry` +
  `defineDefaultParameterTypes`). Regexp sources match the reference exactly so
  that generated regexes are conformant.
  """

  alias Cabbage.CucumberExpression.Errors
  alias Cabbage.CucumberExpression.ParameterType

  @integer_regexps ["-?\\d+", "\\d+"]
  @float_regexp "(?=.*\\d.*)[-+]?\\d*(?:\\.(?=\\d.*))?\\d*(?:\\d+[E][+-]?\\d+)?"
  @word_regexp "[^\\s]+"
  @string_regexp "\"([^\"\\\\]*(\\\\.[^\"\\\\]*)*)\"|'([^'\\\\]*(\\\\.[^'\\\\]*)*)'"
  @anonymous_regexp ".*"

  @opaque t :: %{optional(String.t()) => ParameterType.t()}

  @doc "Returns a registry seeded with the built-in parameter types."
  @spec new() :: t()
  def new do
    [
      ParameterType.new(
        name: "int",
        regexps: @integer_regexps,
        transform: &to_integer/1,
        use_for_snippets: true,
        prefer_for_regexp_match: true,
        builtin: true
      ),
      ParameterType.new(
        name: "float",
        regexps: @float_regexp,
        transform: &to_float/1,
        builtin: true
      ),
      ParameterType.new(
        name: "word",
        regexps: @word_regexp,
        transform: &first/1,
        use_for_snippets: false,
        builtin: true
      ),
      ParameterType.new(
        name: "string",
        regexps: @string_regexp,
        transform: &to_string_value/1,
        builtin: true
      ),
      ParameterType.new(
        name: "",
        regexps: @anonymous_regexp,
        transform: &first/1,
        use_for_snippets: false,
        prefer_for_regexp_match: true,
        builtin: true
      ),
      ParameterType.new(name: "double", regexps: @float_regexp, transform: &to_float/1, builtin: true),
      ParameterType.new(
        name: "bigdecimal",
        regexps: @float_regexp,
        transform: &first/1,
        builtin: true
      ),
      ParameterType.new(name: "byte", regexps: @integer_regexps, transform: &to_integer/1, builtin: true),
      ParameterType.new(name: "short", regexps: @integer_regexps, transform: &to_integer/1, builtin: true),
      ParameterType.new(name: "long", regexps: @integer_regexps, transform: &to_integer/1, builtin: true),
      ParameterType.new(
        name: "biginteger",
        regexps: @integer_regexps,
        transform: &to_integer/1,
        builtin: true
      )
    ]
    |> Map.new(&{&1.name, &1})
  end

  @doc "Looks up a parameter type by name, or `nil`."
  @spec lookup_by_type_name(t(), String.t()) :: ParameterType.t() | nil
  def lookup_by_type_name(registry, name), do: Map.get(registry, name)

  @doc "Adds a parameter type, raising if its name is already registered."
  @spec define(t(), ParameterType.t()) :: t()
  def define(registry, %ParameterType{name: name} = type) do
    if Map.has_key?(registry, name) do
      raise Errors.ambiguous_parameter_type(name)
    end

    Map.put(registry, name, type)
  end

  # ---- built-in transforms ---------------------------------------------------

  defp first(values), do: List.first(values)

  defp to_integer([nil | _]), do: nil
  defp to_integer([value | _]), do: String.to_integer(value)
  defp to_integer([]), do: nil

  defp to_float([nil | _]), do: nil
  defp to_float([value | _]), do: parse_float(value)
  defp to_float([]), do: nil

  # Mirrors JS `parseFloat`, which accepts a leading-dot form like ".22" and a
  # leading "+". Elixir's `Float.parse/1` rejects both, so normalise first.
  defp parse_float(value) do
    normalised =
      value
      |> String.replace_prefix("+", "")
      |> add_leading_zero()

    case Float.parse(normalised) do
      {f, _rest} -> f
      :error -> nil
    end
  end

  defp add_leading_zero("." <> _ = v), do: "0" <> v
  defp add_leading_zero("-." <> rest), do: "-0." <> rest
  defp add_leading_zero(v), do: v

  # The string parameter type has two capture-group alternatives (double- and
  # single-quoted). The transform picks whichever participated and unescapes
  # the matching quote character. Mirrors `(s1 || s2 || '').replace(...)`.
  defp to_string_value(values) do
    raw = Enum.find(values, fn v -> v not in [nil, false] end) || ""

    raw
    |> String.replace("\\\"", "\"")
    |> String.replace("\\'", "'")
  end
end
