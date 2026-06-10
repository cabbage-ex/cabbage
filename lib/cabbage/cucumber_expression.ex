defmodule Cabbage.CucumberExpression do
  @moduledoc """
  A real, conformant implementation of Cucumber Expressions.

  This is intentionally isolated under the `Cabbage.CucumberExpression` namespace
  (tokenizer, parser, parameter types, regex generation and matching) so that it
  could later be extracted into its own Hex package. It does not depend on any
  other part of cabbage.

  Pipeline: `tokenize -> parse -> rewrite AST to regex -> match`.

  Ported from cucumber/cucumber-expressions.

      iex> registry = Cabbage.CucumberExpression.ParameterTypeRegistry.new()
      iex> expr = Cabbage.CucumberExpression.compile("I have {int} cukes", registry)
      iex> Cabbage.CucumberExpression.match(expr, "I have 42 cukes")
      [42]
  """

  alias Cabbage.CucumberExpression.{Errors, Parser, ParameterType, ParameterTypeRegistry, TreeRegexp}

  defstruct [:source, :registry, :ast, :tree_regexp, :parameter_types]

  @type t :: %__MODULE__{
          source: String.t(),
          registry: ParameterTypeRegistry.t(),
          ast: map(),
          tree_regexp: %TreeRegexp{},
          parameter_types: [ParameterType.t()]
        }

  # `escapeRegex` reserved set from the reference: \ ^ [ ( { $ . | ? * + } ) ]
  @escape_pattern ~r/([\\\^\[\(\{\$\.\|\?\*\+\}\)\]])/

  @doc """
  Compiles `expression` against `registry`, producing a struct that can be used
  to `match/2`. Raises `Cabbage.CucumberExpression.Errors.CucumberExpressionError`
  for malformed expressions or undefined parameter types.
  """
  @spec compile(String.t(), ParameterTypeRegistry.t()) :: t()
  def compile(expression, registry) do
    ast = Parser.parse(expression)
    {pattern, parameter_types} = rewrite_to_regex(ast, expression, registry, [])

    %__MODULE__{
      source: expression,
      registry: registry,
      ast: ast,
      tree_regexp: TreeRegexp.new(pattern),
      parameter_types: Enum.reverse(parameter_types)
    }
  end

  @doc "The generated anchored regex source string for `expression`."
  @spec to_regex(String.t(), ParameterTypeRegistry.t()) :: String.t()
  def to_regex(expression, registry) do
    ast = Parser.parse(expression)
    {pattern, _types} = rewrite_to_regex(ast, expression, registry, [])
    pattern
  end

  @doc """
  The `{type}` parameter type names referenced by `expression`, in order of appearance.

  Parses the expression (raising on malformed syntax) but does *not* require the types
  to be registered — callers can use this to detect an undefined parameter type before
  `compile/2` would raise. For example, `{flight} from {airport}` returns
  `["flight", "airport"]`.
  """
  @spec parameter_type_names(String.t()) :: [String.t()]
  def parameter_type_names(expression) do
    expression
    |> Parser.parse()
    |> collect_parameter_names([])
    |> Enum.reverse()
  end

  defp collect_parameter_names(%{"type" => "PARAMETER_NODE"} = node, acc) do
    [parameter_name(node) | acc]
  end

  defp collect_parameter_names(%{"nodes" => nodes}, acc) when is_list(nodes) do
    Enum.reduce(nodes, acc, &collect_parameter_names/2)
  end

  defp collect_parameter_names(_node, acc), do: acc

  @doc """
  Matches `text` against a compiled expression, returning the list of transformed
  argument values, or `nil` if there is no match.
  """
  @spec match(t(), String.t()) :: [any()] | nil
  def match(%__MODULE__{tree_regexp: tree, parameter_types: types}, text) do
    case TreeRegexp.match(tree, text) do
      nil ->
        nil

      group ->
        arg_groups = group.children || []

        if length(arg_groups) != length(types) do
          raise Errors.CucumberExpressionError,
            message:
              "Group has #{length(arg_groups)} capture groups, but there were " <>
                "#{length(types)} parameter types"
        end

        Enum.zip(arg_groups, types)
        |> Enum.map(fn {g, type} -> ParameterType.transform(type, TreeRegexp.values(g)) end)
    end
  end

  # ---- AST -> regex (with structural validation) -----------------------------
  #
  # Returns {regex_string, parameter_types_acc} where the accumulator collects
  # parameter types in reverse order of appearance.

  defp rewrite_to_regex(%{"type" => "EXPRESSION_NODE", "nodes" => nodes}, expr, registry, acc) do
    {inner, acc} = rewrite_seq(nodes, expr, registry, acc, "")
    {"^" <> inner <> "$", acc}
  end

  defp rewrite_to_regex(%{"type" => "TEXT_NODE", "token" => text}, _expr, _registry, acc) do
    {escape_regex(text), acc}
  end

  defp rewrite_to_regex(%{"type" => "OPTIONAL_NODE"} = node, expr, registry, acc) do
    assert_no_parameters!(node, expr, &Errors.problem(&1, &2, &3, parameter_in_optional_msg()))
    assert_no_optionals!(node, expr)
    assert_not_empty!(node, expr, &Errors.problem(&1, &2, &3, optional_empty_msg()))

    {inner, acc} = rewrite_seq(node["nodes"], expr, registry, acc, "")
    {"(?:" <> inner <> ")?", acc}
  end

  defp rewrite_to_regex(%{"type" => "ALTERNATION_NODE"} = node, expr, registry, acc) do
    Enum.each(node["nodes"], fn alternative ->
      if alternative["nodes"] == [] do
        raise alternative_empty_error(alternative, expr)
      end

      assert_not_empty!(
        alternative,
        expr,
        &Errors.problem(&1, &2, &3, alternative_only_optionals_msg())
      )
    end)

    {parts, acc} =
      Enum.reduce(node["nodes"], {[], acc}, fn alt, {parts, acc} ->
        {s, acc} = rewrite_to_regex(alt, expr, registry, acc)
        {[s | parts], acc}
      end)

    {"(?:" <> Enum.join(Enum.reverse(parts), "|") <> ")", acc}
  end

  defp rewrite_to_regex(%{"type" => "ALTERNATIVE_NODE", "nodes" => nodes}, expr, registry, acc) do
    rewrite_seq(nodes, expr, registry, acc, "")
  end

  defp rewrite_to_regex(%{"type" => "PARAMETER_NODE"} = node, expr, registry, acc) do
    name = parameter_name(node)

    case ParameterTypeRegistry.lookup_by_type_name(registry, name) do
      nil ->
        raise Errors.undefined_parameter_type(expr, node["start"], node["end"], name)

      %ParameterType{regexps: regexps} = type ->
        regex =
          case regexps do
            [single] -> "(" <> single <> ")"
            many -> "((?:" <> Enum.join(many, ")|(?:") <> "))"
          end

        {regex, [type | acc]}
    end
  end

  defp rewrite_seq(nodes, expr, registry, acc, out) do
    Enum.reduce(nodes, {out, acc}, fn node, {out, acc} ->
      {s, acc} = rewrite_to_regex(node, expr, registry, acc)
      {out <> s, acc}
    end)
    |> then(fn {out, acc} -> {out, acc} end)
  end

  defp escape_regex(text), do: Regex.replace(@escape_pattern, text, "\\\\\\1")

  # A parameter node's name is the concatenation of its TEXT_NODE tokens.
  defp parameter_name(node) do
    node["nodes"]
    |> Enum.map(& &1["token"])
    |> Enum.join()
  end

  # ---- assertions (mirror CucumberExpression.ts) -----------------------------

  defp assert_not_empty!(node, expr, build_error) do
    has_text? = Enum.any?(node["nodes"] || [], &(&1["type"] == "TEXT_NODE"))

    unless has_text? do
      raise build_error.(expr, node["start"], node["end"] - 1)
    end
  end

  defp assert_no_parameters!(node, expr, build_error) do
    case Enum.find(node["nodes"] || [], &(&1["type"] == "PARAMETER_NODE")) do
      nil -> :ok
      param -> raise build_error.(expr, param["start"], param["end"] - 1)
    end
  end

  defp assert_no_optionals!(node, expr) do
    case Enum.find(node["nodes"] || [], &(&1["type"] == "OPTIONAL_NODE")) do
      nil ->
        :ok

      opt ->
        raise Errors.problem(expr, opt["start"], opt["end"] - 1, optional_in_optional_msg())
    end
  end

  # Empty alternative blames the separator boundary: a single caret at the
  # alternative's start column.
  defp alternative_empty_error(alternative, expr) do
    Errors.problem(expr, alternative["start"], nil, alternative_empty_msg())
  end

  # ---- error message bodies --------------------------------------------------

  defp optional_empty_msg do
    "An optional must contain some text.\n" <>
      "If you did not mean to use an optional you can use '\\(' to escape the '('"
  end

  defp optional_in_optional_msg do
    "An optional may not contain an other optional.\n" <>
      "If you did not mean to use an optional type you can use '\\(' to escape the '('. " <>
      "For more complicated expressions consider using a regular expression instead."
  end

  defp parameter_in_optional_msg do
    "An optional may not contain a parameter type.\n" <>
      "If you did not mean to use an parameter type you can use '\\{' to escape the '{'"
  end

  defp alternative_empty_msg do
    "Alternative may not be empty.\n" <>
      "If you did not mean to use an alternative you can use '\\/' to escape the '/'"
  end

  defp alternative_only_optionals_msg do
    "An alternative may not exclusively contain optionals.\n" <>
      "If you did not mean to use an optional you can use '\\(' to escape the '('"
  end
end
