defmodule Cabbage.CucumberExpression.Tokenizer do
  @moduledoc """
  Tokenizes a Cucumber Expression into a list of token maps.

  Each token is a map with string keys matching the language-neutral testdata
  shape: `%{"type" => ..., "start" => ..., "end" => ..., "text" => ...}` where
  `start`/`end` are zero-based codepoint offsets (`end` is exclusive).

  Token types: `START_OF_LINE`, `END_OF_LINE`, `WHITE_SPACE`, `BEGIN_OPTIONAL`,
  `END_OPTIONAL`, `BEGIN_PARAMETER`, `END_PARAMETER`, `ALTERNATION`, `TEXT`.

  Ported from cucumber/cucumber-expressions.
  """

  alias Cabbage.CucumberExpression.Errors

  @escape_character "\\"
  @alternation "/"
  @begin_parameter "{"
  @end_parameter "}"
  @begin_optional "("
  @end_optional ")"

  @doc """
  Tokenizes `expression`, returning a list of token maps. Raises
  `Cabbage.CucumberExpression.Errors.CucumberExpressionError` on a malformed
  escape sequence.
  """
  @spec tokenize(String.t()) :: [map()]
  def tokenize(expression) do
    codepoints = String.codepoints(expression)

    tokens =
      [start_token()]
      |> scan(codepoints, 0, [], nil, expression)

    Enum.reverse(tokens)
  end

  defp start_token, do: token("START_OF_LINE", 0, 0, "")

  # End of input: flush any pending buffer, then append END_OF_LINE.
  defp scan(tokens, [], index, buffer, buffer_start, _expression) do
    tokens = flush(tokens, buffer, buffer_start, index)
    [token("END_OF_LINE", index, index, "") | tokens]
  end

  # Escape sequence.
  defp scan(tokens, [@escape_character | rest], index, buffer, buffer_start, expression) do
    case rest do
      [] ->
        raise Errors.problem(
                expression,
                index,
                nil,
                "The end of line can not be escaped.\nYou can use '\\\\' to escape the '\\'"
              )

      [next | tail] ->
        if escapable?(next) do
          start = buffer_start || index
          scan(tokens, tail, index + 2, buffer ++ [next], start, expression)
        else
          raise Errors.problem(
                  expression,
                  index + 1,
                  nil,
                  "Only the characters '{', '}', '(', ')', '\\', '/' and whitespace can be escaped.\n" <>
                    "If you did mean to use an '\\' you can use '\\\\' to escape it"
                )
        end
    end
  end

  # Reserved single-character tokens flush the buffer and emit their own token.
  defp scan(tokens, [char | rest], index, buffer, buffer_start, expression) do
    cond do
      reserved_type(char) != nil ->
        tokens = flush(tokens, buffer, buffer_start, index)
        tokens = [token(reserved_type(char), index, index + 1, char) | tokens]
        scan(tokens, rest, index + 1, [], nil, expression)

      whitespace?(char) ->
        tokens = flush(tokens, buffer, buffer_start, index)
        tokens = [token("WHITE_SPACE", index, index + 1, char) | tokens]
        scan(tokens, rest, index + 1, [], nil, expression)

      true ->
        start = buffer_start || index
        scan(tokens, rest, index + 1, buffer ++ [char], start, expression)
    end
  end

  # Emit a TEXT token from the accumulated buffer (if any).
  defp flush(tokens, [], _buffer_start, _index), do: tokens

  defp flush(tokens, buffer, buffer_start, index) do
    [token("TEXT", buffer_start, index, Enum.join(buffer)) | tokens]
  end

  defp reserved_type(@begin_parameter), do: "BEGIN_PARAMETER"
  defp reserved_type(@end_parameter), do: "END_PARAMETER"
  defp reserved_type(@begin_optional), do: "BEGIN_OPTIONAL"
  defp reserved_type(@end_optional), do: "END_OPTIONAL"
  defp reserved_type(@alternation), do: "ALTERNATION"
  defp reserved_type(_), do: nil

  defp escapable?(char) do
    reserved_type(char) != nil or char == @escape_character or whitespace?(char)
  end

  defp whitespace?(char), do: char == " " or String.match?(char, ~r/^\s$/u)

  defp token(type, start, stop, text) do
    %{"type" => type, "start" => start, "end" => stop, "text" => text}
  end
end
