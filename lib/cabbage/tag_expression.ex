defmodule Cabbage.TagExpression do
  @moduledoc """
  A spec-conformant implementation of the Cucumber **tag expression** language —
  the boolean mini-language used to filter scenarios by tag, e.g.

      @smoke and not @wip
      (@a or @b) and @c

  This is a self-contained engine with no dependencies on the rest of Cabbage, so
  it can later be extracted to its own Hex package. It mirrors the reference
  implementation (cucumber/tag-expressions) closely enough to pass that project's
  cross-language conformance corpus verbatim — see
  `test/conformance/tag_expressions/`.

  ## Grammar

    * the simplest expression is a bare tag, e.g. `@a` (a tag is just a string —
      the leading `@` is not special to the parser)
    * `not <expr>` — unary negation (right-associative, highest precedence)
    * `<expr> and <expr>` — conjunction (left-associative)
    * `<expr> or <expr>` — disjunction (left-associative, lowest precedence)
    * `( <expr> )` — grouping
    * an **empty** expression is valid and always evaluates to `true`

  Precedence, high to low: `not` > `and` > `or`.

  ## Escaping

  Backslash escapes let a tag name contain otherwise-significant characters:
  `\\\\` (backslash), `\\(`, `\\)`, and an escaped whitespace character. For
  example `x\\(1\\)` is a single tag named `x(1)`.

  ## Usage

      iex> {:ok, expr} = Cabbage.TagExpression.parse("@a and not @b")
      iex> Cabbage.TagExpression.evaluate(expr, ["@a"])
      true
      iex> Cabbage.TagExpression.evaluate(expr, ["@a", "@b"])
      false
      iex> to_string(expr)
      "( @a and not ( @b ) )"

  Invalid expressions return an `{:error, message}` tuple whose message matches the
  reference wording exactly:

      iex> Cabbage.TagExpression.parse("@a and")
      {:error, ~s(Tag expression "@a and" could not be parsed because of syntax error: Expected operand.)}
  """

  alias Cabbage.TagExpression.{And, Literal, Not, Or, Parser, True}

  @typedoc """
  A parsed tag expression node. Opaque — build it with `parse/1` and consume it
  with `evaluate/2` or `to_string/1`; do not depend on the internal node shape.
  """
  @opaque t :: True.t() | Literal.t() | Not.t() | And.t() | Or.t()

  @doc """
  Parse a tag expression string into an AST node.

  Returns `{:ok, node}` on success or `{:error, message}` with the exact
  reference-wording syntax-error message on failure.
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  defdelegate parse(expression), to: Parser

  @doc """
  Like `parse/1` but raises `Cabbage.TagExpression.SyntaxError` on failure.
  """
  @spec parse!(String.t()) :: t()
  def parse!(expression) do
    case parse(expression) do
      {:ok, node} -> node
      {:error, message} -> raise Cabbage.TagExpression.SyntaxError, message: message
    end
  end

  @doc """
  Evaluate a parsed expression against a list of tags that are present.

  Accepts either a parsed node or a raw expression string (parsed with `parse!/1`).
  """
  @spec evaluate(t() | String.t(), [String.t()]) :: boolean()
  def evaluate(expression, tags) when is_binary(expression),
    do: evaluate(parse!(expression), tags)

  def evaluate(node, tags) when is_list(tags),
    do: Cabbage.TagExpression.Node.evaluate(node, tags)
end

defmodule Cabbage.TagExpression.SyntaxError do
  @moduledoc "Raised by `Cabbage.TagExpression.parse!/1` on an invalid expression."
  defexception [:message]
end

defprotocol Cabbage.TagExpression.Node do
  @moduledoc false
  # Internal protocol both evaluation and rendering dispatch on. `to_string/1`
  # for the public canonical form goes through `String.Chars` (see below).
  @spec evaluate(t(), [String.t()]) :: boolean()
  def evaluate(node, tags)
end

defmodule Cabbage.TagExpression.True do
  @moduledoc false
  # The empty expression: always true, renders to "".
  defstruct []
  @type t :: %__MODULE__{}
end

defmodule Cabbage.TagExpression.Literal do
  @moduledoc false
  defstruct [:value]
  @type t :: %__MODULE__{value: String.t()}
end

defmodule Cabbage.TagExpression.Not do
  @moduledoc false
  defstruct [:expression]
  @type t :: %__MODULE__{expression: Cabbage.TagExpression.t()}
end

defmodule Cabbage.TagExpression.And do
  @moduledoc false
  defstruct [:left, :right]
  @type t :: %__MODULE__{left: Cabbage.TagExpression.t(), right: Cabbage.TagExpression.t()}
end

defmodule Cabbage.TagExpression.Or do
  @moduledoc false
  defstruct [:left, :right]
  @type t :: %__MODULE__{left: Cabbage.TagExpression.t(), right: Cabbage.TagExpression.t()}
end

defimpl Cabbage.TagExpression.Node, for: Cabbage.TagExpression.True do
  def evaluate(_node, _tags), do: true
end

defimpl Cabbage.TagExpression.Node, for: Cabbage.TagExpression.Literal do
  def evaluate(%{value: value}, tags), do: value in tags
end

defimpl Cabbage.TagExpression.Node, for: Cabbage.TagExpression.Not do
  def evaluate(%{expression: expression}, tags),
    do: not Cabbage.TagExpression.Node.evaluate(expression, tags)
end

defimpl Cabbage.TagExpression.Node, for: Cabbage.TagExpression.And do
  def evaluate(%{left: left, right: right}, tags),
    do:
      Cabbage.TagExpression.Node.evaluate(left, tags) and
        Cabbage.TagExpression.Node.evaluate(right, tags)
end

defimpl Cabbage.TagExpression.Node, for: Cabbage.TagExpression.Or do
  def evaluate(%{left: left, right: right}, tags),
    do:
      Cabbage.TagExpression.Node.evaluate(left, tags) or
        Cabbage.TagExpression.Node.evaluate(right, tags)
end

defimpl String.Chars, for: Cabbage.TagExpression.True do
  def to_string(_node), do: ""
end

defimpl String.Chars, for: Cabbage.TagExpression.Literal do
  # Re-escape the canonical name: backslashes first, then parens, then whitespace.
  def to_string(%{value: value}) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
    |> then(&Regex.replace(~r/\s/, &1, "\\\\ "))
  end
end

defimpl String.Chars, for: Cabbage.TagExpression.Not do
  # Binary children already render their own "( ... )", so don't double-wrap them.
  def to_string(%{expression: %mod{} = expression})
      when mod in [Cabbage.TagExpression.And, Cabbage.TagExpression.Or] do
    "not #{expression}"
  end

  def to_string(%{expression: expression}), do: "not ( #{expression} )"
end

defimpl String.Chars, for: Cabbage.TagExpression.And do
  def to_string(%{left: left, right: right}), do: "( #{left} and #{right} )"
end

defimpl String.Chars, for: Cabbage.TagExpression.Or do
  def to_string(%{left: left, right: right}), do: "( #{left} or #{right} )"
end
