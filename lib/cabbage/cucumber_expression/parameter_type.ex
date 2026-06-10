defmodule Cabbage.CucumberExpression.ParameterType do
  @moduledoc """
  A Cucumber Expression parameter type: a name, one or more regexps, and a
  transform that converts matched capture strings into a value.

  Ported from cucumber/cucumber-expressions. `regexps` is always normalised to a
  list of regexp *source strings* (no anchors, no capture groups added here).
  """

  @enforce_keys [:name, :regexps]
  defstruct name: nil,
            regexps: [],
            transform: nil,
            use_for_snippets: true,
            prefer_for_regexp_match: false,
            builtin: false

  @type t :: %__MODULE__{
          name: String.t() | nil,
          regexps: [String.t()],
          transform: ([String.t() | nil] -> any()) | nil,
          use_for_snippets: boolean(),
          prefer_for_regexp_match: boolean(),
          builtin: boolean()
        }

  @doc """
  Builds a parameter type. `regexps` may be a single string/Regex or a list.
  `transform` receives the list of capture-group string values (or `[nil]` when
  a group did not participate) and returns the converted value.
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    regexps = opts |> Keyword.fetch!(:regexps) |> normalise_regexps()

    %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      regexps: regexps,
      transform: Keyword.get(opts, :transform, fn values -> List.first(values) end),
      use_for_snippets: Keyword.get(opts, :use_for_snippets, true),
      prefer_for_regexp_match: Keyword.get(opts, :prefer_for_regexp_match, false),
      builtin: Keyword.get(opts, :builtin, false)
    }
  end

  defp normalise_regexps(regexps) when is_list(regexps), do: Enum.map(regexps, &source/1)
  defp normalise_regexps(regexp), do: [source(regexp)]

  defp source(%Regex{} = r), do: Regex.source(r)
  defp source(s) when is_binary(s), do: s

  @doc "Applies the parameter type's transform to a list of capture-group strings."
  @spec transform(t(), [String.t() | nil]) :: any()
  def transform(%__MODULE__{transform: fun}, group_values), do: fun.(group_values)
end
