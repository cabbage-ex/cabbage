defmodule Cabbage.CucumberExpression.Parser do
  @moduledoc """
  Parses a tokenized Cucumber Expression into an AST of node maps.

  Nodes are maps with string keys mirroring the language-neutral testdata shape:

      %{"type" => type, "start" => start, "end" => stop, "nodes" => [...]}        # branch
      %{"type" => "TEXT_NODE", "start" => start, "end" => stop, "token" => text}  # leaf

  Node types: `EXPRESSION_NODE`, `ALTERNATION_NODE`, `ALTERNATIVE_NODE`,
  `OPTIONAL_NODE`, `PARAMETER_NODE`, `TEXT_NODE`.

  Ported faithfully from cucumber/cucumber-expressions
  (`CucumberExpressionParser.ts`): a layered recursive-descent parser built from
  `parse_between` / `parse_tokens_until`. Structural validation that depends on
  parameter types (empty optionals, nested optionals, empty alternatives, ...)
  lives in `Cabbage.CucumberExpression`, not here; the parser only raises for an
  unterminated `{`/`(` or a reserved character inside a parameter name.
  """

  alias Cabbage.CucumberExpression.{Errors, Tokenizer}

  # ---- public ----------------------------------------------------------------

  @doc "Tokenizes and parses `expression`, returning the EXPRESSION_NODE map."
  @spec parse(String.t()) :: map()
  def parse(expression) do
    tokens = Tokenizer.tokenize(expression)
    {_consumed, nodes} = parse_expression(expression, tokens)

    eol = List.last(tokens)

    %{
      "type" => "EXPRESSION_NODE",
      "start" => 0,
      "end" => eol["end"],
      "nodes" => nodes
    }
  end

  # cucumber-expression := ( alternation | optional | parameter | text )*
  defp parse_expression(expression, tokens) do
    # tokens[0] is START_OF_LINE, parse until END_OF_LINE.
    parse_tokens_until(
      expression,
      tokens,
      1,
      ["END_OF_LINE"],
      [&parse_alternation/3, &parse_optional/3, &parse_parameter/3, &parse_text/3]
    )
  end

  # ---- combinators -----------------------------------------------------------

  # Runs `parsers` (first non-zero-consumed wins) repeatedly from `start_at`
  # until a token whose type is in `end_types` is reached (not consumed).
  # Returns {consumed, nodes}.
  defp parse_tokens_until(expression, tokens, start_at, end_types, parsers) do
    size = length(tokens)
    do_until(expression, tokens, size, start_at, start_at, end_types, parsers, [])
  end

  defp do_until(expression, tokens, size, current, start_at, end_types, parsers, acc) do
    if current >= size or looking_at_any?(tokens, current, end_types) do
      {current - start_at, Enum.reverse(acc)}
    else
      {consumed, nodes} = run_parsers(parsers, expression, tokens, current)

      if consumed == 0 do
        # Should never happen with correctly-ordered parsers; guards against loops.
        raise "No eligible parser at token #{current}"
      end

      acc = Enum.reduce(nodes, acc, fn n, a -> [n | a] end)
      do_until(expression, tokens, size, current + consumed, start_at, end_types, parsers, acc)
    end
  end

  # ---- text ------------------------------------------------------------------

  defp parse_text(expression, tokens, current) do
    token = Enum.at(tokens, current)

    case token["type"] do
      type when type in ["WHITE_SPACE", "TEXT", "END_PARAMETER", "END_OPTIONAL"] ->
        {1, [text_node(token)]}

      "ALTERNATION" ->
        raise Errors.problem(
                expression,
                token["start"],
                nil,
                "An alternation can not be used inside an optional.\n" <>
                  "If you did not mean to use an alternation you can use '\\/' to escape the '/'. " <>
                  "Otherwise rephrase your expression or consider using a regular expression instead."
              )

      _ ->
        {0, []}
    end
  end

  # ---- name (inside a parameter) --------------------------------------------

  defp parse_name(expression, tokens, current) do
    token = Enum.at(tokens, current)

    case token["type"] do
      type when type in ["WHITE_SPACE", "TEXT"] ->
        {1, [text_node(token)]}

      type
      when type in [
             "BEGIN_OPTIONAL",
             "END_OPTIONAL",
             "BEGIN_PARAMETER",
             "END_PARAMETER",
             "ALTERNATION"
           ] ->
        raise Errors.problem(
                expression,
                token["start"],
                nil,
                "Parameter names may not contain '{', '}', '(', ')', '\\' or '/'.\n" <>
                  "Did you mean to use a regular expression?"
              )

      _ ->
        {0, []}
    end
  end

  # ---- optional / parameter via parse_between --------------------------------

  defp parse_optional(expression, tokens, current) do
    parse_between(
      expression,
      tokens,
      current,
      "OPTIONAL_NODE",
      "BEGIN_OPTIONAL",
      "END_OPTIONAL",
      [&parse_optional/3, &parse_parameter/3, &parse_text/3]
    )
  end

  defp parse_parameter(expression, tokens, current) do
    parse_between(
      expression,
      tokens,
      current,
      "PARAMETER_NODE",
      "BEGIN_PARAMETER",
      "END_PARAMETER",
      [&parse_name/3]
    )
  end

  defp parse_between(expression, tokens, current, node_type, begin_type, end_type, sub_parsers) do
    if not looking_at?(tokens, current, begin_type) do
      {0, []}
    else
      {consumed, nodes} =
        parse_tokens_until(expression, tokens, current + 1, [end_type, "END_OF_LINE"], sub_parsers)

      next = current + 1 + consumed

      if not looking_at?(tokens, next, end_type) do
        begin_token = Enum.at(tokens, current)
        raise missing_end_token(expression, begin_token, begin_type)
      end

      begin_token = Enum.at(tokens, current)
      end_token = Enum.at(tokens, next)

      node = %{
        "type" => node_type,
        "start" => begin_token["start"],
        "end" => end_token["end"],
        "nodes" => nodes
      }

      # consumed = sub-tokens + begin + end
      {next + 1 - current, [node]}
    end
  end

  defp missing_end_token(expression, begin_token, "BEGIN_OPTIONAL") do
    Errors.problem(
      expression,
      begin_token["start"],
      nil,
      "The '(' does not have a matching ')'.\n" <>
        "If you did not intend to use optional text you can use '\\(' to escape the optional text"
    )
  end

  defp missing_end_token(expression, begin_token, "BEGIN_PARAMETER") do
    Errors.problem(
      expression,
      begin_token["start"],
      nil,
      "The '{' does not have a matching '}'.\n" <>
        "If you did not intend to use a parameter you can use '\\{' to escape the a parameter"
    )
  end

  # ---- alternation -----------------------------------------------------------
  #
  # alternation := (?<=left-boundary) alternative* ( '/' alternative* )+ (?=right-boundary)
  # left-boundary  := whitespace | END_PARAMETER | START_OF_LINE
  # right-boundary := whitespace | BEGIN_PARAMETER | END_OF_LINE
  defp parse_alternation(expression, tokens, current) do
    previous = current - 1

    if not looking_at_any?(tokens, previous, ["START_OF_LINE", "WHITE_SPACE", "END_PARAMETER"]) do
      {0, []}
    else
      {consumed, nodes} =
        parse_tokens_until(
          expression,
          tokens,
          current,
          ["WHITE_SPACE", "END_OF_LINE", "BEGIN_PARAMETER"],
          [&parse_alternative_separator/3, &parse_optional/3, &parse_parameter/3, &parse_text/3]
        )

      if not Enum.any?(nodes, &(&1["type"] == "ALTERNATIVE_SEPARATOR")) do
        {0, []}
      else
        start = Enum.at(tokens, current)["start"]
        sub_current = current + consumed
        stop = Enum.at(tokens, sub_current)["start"]

        node = %{
          "type" => "ALTERNATION_NODE",
          "start" => start,
          "end" => stop,
          "nodes" => split_alternatives(start, stop, nodes)
        }

        {consumed, [node]}
      end
    end
  end

  defp parse_alternative_separator(_expression, tokens, current) do
    if not looking_at?(tokens, current, "ALTERNATION") do
      {0, []}
    else
      token = Enum.at(tokens, current)

      {1,
       [
         %{
           "type" => "ALTERNATIVE_SEPARATOR",
           "start" => token["start"],
           "end" => token["end"],
           "token" => token["text"]
         }
       ]}
    end
  end

  # Split a flat node list (containing ALTERNATIVE_SEPARATOR markers) into
  # ALTERNATIVE_NODEs. The reference uses the separators' indices as the
  # boundary positions for the alternative spans.
  defp split_alternatives(start, stop, nodes) do
    {separators, groups} = collect_alternatives(nodes, [], [], [])
    create_alternative_nodes(start, stop, separators, groups)
  end

  defp collect_alternatives([], current, separators, groups) do
    {Enum.reverse(separators), Enum.reverse([Enum.reverse(current) | groups])}
  end

  defp collect_alternatives([%{"type" => "ALTERNATIVE_SEPARATOR"} = sep | rest], current, seps, groups) do
    collect_alternatives(rest, [], [sep | seps], [Enum.reverse(current) | groups])
  end

  defp collect_alternatives([node | rest], current, seps, groups) do
    collect_alternatives(rest, [node | current], seps, groups)
  end

  # Build ALTERNATIVE_NODE spans. For alternative i: start is the previous
  # separator's end (or the alternation start for the first), end is the next
  # separator's start (or the alternation end for the last).
  defp create_alternative_nodes(start, stop, separators, groups) do
    n = length(groups)

    groups
    |> Enum.with_index()
    |> Enum.map(fn {group, i} ->
      alt_start = if i == 0, do: start, else: Enum.at(separators, i - 1)["end"]
      alt_end = if i == n - 1, do: stop, else: Enum.at(separators, i)["start"]

      %{
        "type" => "ALTERNATIVE_NODE",
        "start" => alt_start,
        "end" => alt_end,
        "nodes" => group
      }
    end)
  end

  # ---- helpers ---------------------------------------------------------------

  defp looking_at?(tokens, at, type) do
    cond do
      at < 0 -> type == "START_OF_LINE"
      at >= length(tokens) -> type == "END_OF_LINE"
      true -> Enum.at(tokens, at)["type"] == type
    end
  end

  defp looking_at_any?(tokens, at, types) do
    Enum.any?(types, &looking_at?(tokens, at, &1))
  end

  defp text_node(token) do
    %{
      "type" => "TEXT_NODE",
      "start" => token["start"],
      "end" => token["end"],
      "token" => token["text"]
    }
  end

  # Try each parser in order; first one that consumes tokens wins.
  defp run_parsers([], _expression, _tokens, _current), do: {0, []}

  defp run_parsers([parser | rest], expression, tokens, current) do
    case parser.(expression, tokens, current) do
      {0, []} -> run_parsers(rest, expression, tokens, current)
      {consumed, nodes} -> {consumed, nodes}
    end
  end
end
