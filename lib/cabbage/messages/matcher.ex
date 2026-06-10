defmodule Cabbage.Messages.Matcher do
  @moduledoc """
  Matches a pickle step's text against the registered step definitions and, for each
  matching definition, recovers the cucumber-messages `stepMatchArguments` (the
  top-level capture groups with their `start` offset, captured `value`, and — for
  Cucumber Expressions — `parameterTypeName`).

  The runner uses the *count* of matches to decide a step's fate:

    * 0 matches  -> `:undefined`
    * 1 match    -> `:defined` (run the definition)
    * >1 matches -> `:ambiguous`
  """

  alias Cabbage.CucumberExpression
  alias Cabbage.CucumberExpression.ParameterType
  alias Cabbage.CucumberExpression.TreeRegexp
  alias Cabbage.Messages.StepRegistry
  alias Cabbage.Messages.StepRegistry.StepDefinition

  import Cabbage.Messages.MapHelpers, only: [put_unless_nil: 3]

  @type match :: %{definition: StepDefinition.t(), arguments: [map()], values: [term()]}

  @doc """
  All step definitions whose pattern matches `text`, paired with their match arguments.

  Returns a list of `%{definition:, arguments:, values:}` in registration order.
  `arguments` is the cucumber-messages `stepMatchArguments` shape; `values` are the
  transformed argument values to pass to the definition's run function.
  """
  @spec matches(StepRegistry.t(), String.t()) :: [match()]
  def matches(%StepRegistry{} = registry, text) do
    registry
    |> StepRegistry.definitions()
    |> Enum.flat_map(fn definition ->
      case match_one(definition, text) do
        nil -> []
        match -> [match]
      end
    end)
  end

  # An :undefined definition references an unregistered parameter type; it never matches,
  # so the step is reported UNDEFINED (and the runner emits an undefinedParameterType message).
  defp match_one(%StepDefinition{pattern_kind: :undefined}, _text), do: nil

  defp match_one(%StepDefinition{pattern_kind: :cucumber_expression, compiled: expr} = def, text) do
    %CucumberExpression{tree_regexp: tree, parameter_types: types} = expr

    case TreeRegexp.match_with_index(tree, text) do
      nil ->
        nil

      group ->
        arg_groups = group.children || []

        # Transformed values (int -> integer, string -> unquoted) feed the step function;
        # the raw group tree feeds stepMatchArguments.
        values =
          arg_groups
          |> Enum.zip(types)
          |> Enum.map(fn {g, type} -> ParameterType.transform(type, group_values(g)) end)

        arguments =
          arg_groups
          |> Enum.zip(types)
          |> Enum.map(fn {g, type} -> argument(g, type.name) end)

        %{definition: def, arguments: arguments, values: values}
    end
  end

  defp match_one(%StepDefinition{pattern_kind: :regular_expression, compiled: regex} = def, text) do
    tree = TreeRegexp.new(Regex.source(regex))

    case TreeRegexp.match_with_index(tree, text) do
      nil ->
        nil

      group ->
        arg_groups = group.children || []
        values = Enum.map(arg_groups, & &1.value)
        arguments = Enum.map(arg_groups, &argument(&1, nil))
        %{definition: def, arguments: arguments, values: values}
    end
  end

  # A group's capture-string values for parameter-type transforms: its children's values
  # (e.g. the two alternation arms of `{string}`), or its own value when it has no children.
  defp group_values(%{children: nil, value: value}), do: [value]
  defp group_values(%{children: children}), do: Enum.map(children, & &1.value)

  # A `stepMatchArgument`: a recursive `group` (start + value + nested children) plus an
  # optional parameterTypeName. The nested children mirror the parameter type's own capture
  # groups (e.g. `{string}`'s quote-alternation), exactly as the cucumber-messages goldens
  # serialize them; absent start/value/children are omitted.
  defp argument(group, parameter_type_name) do
    %{"group" => group_json(group)}
    |> put_unless_nil("parameterTypeName", parameter_type_name)
  end

  defp group_json(%{start: start, value: value} = group) do
    children = Map.get(group, :children)

    %{}
    |> put_unless_nil("start", start)
    |> put_unless_nil("value", value)
    |> put_unless_nil("children", children && Enum.map(children, &group_json/1))
  end
end
