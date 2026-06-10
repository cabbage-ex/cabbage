defmodule Cabbage.CucumberExpression.Errors do
  @moduledoc """
  Exceptions raised by the Cucumber Expression engine.

  The messages mirror the wording produced by the reference implementations
  (cucumber/cucumber-expressions) so that they are conformant with the official,
  language-neutral test suite.
  """

  defmodule CucumberExpressionError do
    @moduledoc "Base error for all Cucumber Expression problems."
    defexception [:message]

    @typedoc "A Cucumber Expression error exception struct."
    @type t :: %__MODULE__{message: String.t()}
  end

  @doc """
  Builds the multi-line "problem at column N" message used by the reference
  parser/tokenizer for both single-column and ranged problems.

  `index` and `to_index` are zero-based codepoint offsets into `expression`.
  When `to_index` is `nil` (or equal to `index`) a single caret is drawn,
  otherwise a `^----^` range pointer spanning the two columns is drawn.
  """
  @spec problem(String.t(), non_neg_integer(), non_neg_integer() | nil, String.t()) ::
          CucumberExpressionError.t()
  def problem(expression, index, to_index, message) do
    pointer = build_pointer(index, to_index)
    column = index + 1

    full =
      "This Cucumber Expression has a problem at column #{column}:\n\n" <>
        expression <> "\n" <> pointer <> "\n" <> message

    %CucumberExpressionError{message: full}
  end

  defp build_pointer(index, to_index) when is_nil(to_index) or to_index <= index do
    String.duplicate(" ", index) <> "^"
  end

  defp build_pointer(index, to_index) do
    width = to_index - index
    String.duplicate(" ", index) <> "^" <> String.duplicate("-", width - 1) <> "^"
  end

  @doc "Undefined parameter type, pointing at the `{...}` span."
  def undefined_parameter_type(expression, start, stop, type_name) do
    problem(
      expression,
      start,
      stop - 1,
      "Undefined parameter type '#{type_name}'.\nPlease register a ParameterType for '#{type_name}'"
    )
  end

  @doc "An already-registered parameter type was registered again."
  def ambiguous_parameter_type(name) do
    %CucumberExpressionError{
      message: "There is already a parameter type with name #{name}"
    }
  end
end
