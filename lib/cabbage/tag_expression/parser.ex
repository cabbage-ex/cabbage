defmodule Cabbage.TagExpression.Parser do
  @moduledoc false
  # Tokenizer + shunting-yard parser for the tag expression language. A faithful
  # port of the reference implementation (cucumber/tag-expressions, Ruby), so the
  # error messages and operator-precedence behaviour match byte-for-byte.
  #
  # Internally we signal syntax errors by throwing `{:tag_expression_error, msg}`
  # and catch it at the `parse/1` boundary, turning it into `{:error, msg}`. This
  # mirrors the reference's raise-on-error flow while keeping the hot path
  # (token reduction) free of `{:ok, _}` plumbing.

  alias Cabbage.TagExpression.{And, Literal, Not, Or, True}

  # token => {kind, precedence, assoc}. assoc is irrelevant for parens.
  @operators %{
    "or" => {:binary, 0, :left},
    "and" => {:binary, 1, :left},
    "not" => {:unary, 2, :right},
    ")" => {:close_paren, -1, nil},
    "(" => {:open_paren, 1, nil}
  }

  @doc """
  Parse an expression string into an AST node, returning `{:ok, node}` or
  `{:error, message}`.
  """
  @spec parse(String.t()) :: {:ok, Cabbage.TagExpression.t()} | {:error, String.t()}
  def parse(expression) when is_binary(expression) do
    {:ok, do_parse(expression)}
  catch
    {:tag_expression_error, message} -> {:error, message}
  end

  defp do_parse(expression) do
    case tokenize(expression) do
      [] ->
        %True{}

      tokens ->
        # State: {operator_stack, operand_stack, expected_token_type}. We thread
        # `expected` explicitly exactly as the reference does (starting at
        # :operand), rather than reconstructing it from the stacks.
        {operators, operands, _expected} =
          Enum.reduce(tokens, {[], [], :operand}, fn token, {operators, operands, expected} ->
            handle_token(token, expression, operators, operands, expected)
          end)

        operands = drain_operators(operators, operands, expression)

        case operands do
          [node] -> node
          # Reachable only on internal invariant violations; defensive.
          _ -> err(expression, "Expected operand.")
        end
    end
  end

  # --- Tokenizer -----------------------------------------------------------

  # Splits on whitespace and (unescaped) parens; honours backslash escapes for
  # `\\`, `\(`, `\)` and escaped whitespace. Whitespace is a separator and is
  # never emitted as a token; parens are emitted as their own tokens.
  #
  # `acc` is `{reversed_tokens, current_token, escaped?}`. We accumulate tokens in
  # reverse for cheap prepends and `Enum.reverse/1` once at the end.
  defp tokenize(expression) do
    {tokens, current, _escaped} =
      expression
      |> String.graphemes()
      |> Enum.reduce({[], "", false}, fn char, acc -> tokenize_char(char, acc, expression) end)

    flush(tokens, current) |> Enum.reverse()
  end

  # Previous char was a backslash: this char must be escapable.
  defp tokenize_char(char, {tokens, current, true}, expression) do
    if escapable?(char),
      do: {tokens, current <> char, false},
      else: err(expression, ~s(Illegal escape before "#{char}".))
  end

  defp tokenize_char("\\", {tokens, current, false}, _expression),
    do: {tokens, current, true}

  defp tokenize_char(char, {tokens, current, false}, _expression) when char in ["(", ")"],
    do: {[char | flush(tokens, current)], "", false}

  defp tokenize_char(char, {tokens, current, false}, _expression) do
    if whitespace?(char),
      do: {flush(tokens, current), "", false},
      else: {tokens, current <> char, false}
  end

  # Prepend the in-progress token (if any) onto the reversed token list.
  defp flush(tokens, ""), do: tokens
  defp flush(tokens, current), do: [current | tokens]

  defp escapable?(char), do: char in ["(", ")", "\\"] or whitespace?(char)

  defp whitespace?(char), do: Regex.match?(~r/^\s$/u, char)

  # --- Shunting-yard token handling ---------------------------------------
  #
  # State is `{operator_stack, operand_stack}` plus an implicit "expected next
  # token type" we derive from the operand stack via the same `check/3` the
  # reference uses. We thread the expected type explicitly to match the reference
  # exactly (it distinguishes the two "Expected" messages by position, not by
  # inspecting the stacks).

  # Returns `{operator_stack, operand_stack, next_expected_type}`. Each clause
  # `check/3`s the current `expected` against what this token requires, mirroring
  # the reference's `handle_*` methods (which return the next expected type).
  defp handle_token(token, expression, operators, operands, expected) do
    case Map.fetch(@operators, token) do
      {:ok, {:unary, _, _}} ->
        check(expression, expected, :operand)
        {[token | operators], operands, :operand}

      {:ok, {:binary, _, _}} ->
        check(expression, expected, :operator)
        {operators, operands} = pop_while_lower(token, operators, operands, expression)
        {[token | operators], operands, :operand}

      {:ok, {:open_paren, _, _}} ->
        check(expression, expected, :operand)
        {[token | operators], operands, :operand}

      {:ok, {:close_paren, _, _}} ->
        check(expression, expected, :operator)
        {operators, operands} = handle_close_paren(operators, operands, expression)
        {operators, operands, :operator}

      :error ->
        check(expression, expected, :operand)
        {operators, [%Literal{value: token} | operands], :operator}
    end
  end

  defp pop_while_lower(token, [top | rest] = operators, operands, expression) do
    if operator?(top) and lower_precedence?(token, top) do
      operands = build(top, operands, expression)
      pop_while_lower(token, rest, operands, expression)
    else
      {operators, operands}
    end
  end

  defp pop_while_lower(_token, [], operands, _expression), do: {[], operands}

  defp handle_close_paren(operators, operands, expression) do
    {operators, operands} = pop_until_open(operators, operands, expression)

    case operators do
      [] -> err(expression, "Unmatched ).")
      ["(" | rest] -> {rest, operands}
    end
  end

  defp pop_until_open(["(" | _] = operators, operands, _expression), do: {operators, operands}
  defp pop_until_open([] = operators, operands, _expression), do: {operators, operands}

  defp pop_until_open([top | rest], operands, expression) do
    operands = build(top, operands, expression)
    pop_until_open(rest, operands, expression)
  end

  defp drain_operators([], operands, _expression), do: operands

  defp drain_operators(["(" | _], _operands, expression),
    do: err(expression, "Unmatched (.")

  defp drain_operators([top | rest], operands, expression) do
    operands = build(top, operands, expression)
    drain_operators(rest, operands, expression)
  end

  # --- AST construction ----------------------------------------------------

  defp build("and", operands, expression) do
    {[right, left], rest} = pop_operands(operands, 2, expression)
    [%And{left: left, right: right} | rest]
  end

  defp build("or", operands, expression) do
    {[right, left], rest} = pop_operands(operands, 2, expression)
    [%Or{left: left, right: right} | rest]
  end

  defp build("not", operands, expression) do
    {[operand], rest} = pop_operands(operands, 1, expression)
    [%Not{expression: operand} | rest]
  end

  defp pop_operands(operands, amount, expression) do
    if length(operands) < amount do
      err(expression, "Expected operand.")
    else
      Enum.split(operands, amount)
    end
  end

  # --- Precedence helpers --------------------------------------------------

  defp operator?(token) do
    case Map.fetch(@operators, token) do
      {:ok, {:unary, _, _}} -> true
      {:ok, {:binary, _, _}} -> true
      _ -> false
    end
  end

  defp lower_precedence?(token, top) do
    {_, prec, assoc} = Map.fetch!(@operators, token)
    {_, top_prec, _} = Map.fetch!(@operators, top)

    case assoc do
      :left -> prec <= top_prec
      :right -> prec < top_prec
    end
  end

  defp check(_expression, expected, expected), do: :ok

  defp check(expression, expected, _actual),
    do: err(expression, "Expected #{expected}.")

  defp err(expression, detail) do
    message =
      ~s(Tag expression "#{expression}" could not be parsed because of syntax error: #{detail})

    throw({:tag_expression_error, message})
  end
end
