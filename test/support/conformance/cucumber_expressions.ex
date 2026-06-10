defmodule Cabbage.Conformance.CucumberExpressions do
  @moduledoc """
  Loads the vendored Cucumber Expressions testdata and grades the engine against
  each category. Shared by `mix conformance.expressions` and the tagged
  conformance ExUnit tests.

  Categories: `matching`, `parser`, `tokenizer`, `transformation`, `regex`.
  Each case is graded to `:ok` (engine output matched the expected value or the
  expected exception was raised) or `{:fail, reason}`.
  """

  alias Cabbage.CucumberExpression
  alias Cabbage.CucumberExpression.{Parser, ParameterTypeRegistry, Tokenizer}
  alias Cabbage.CucumberExpression.Errors.CucumberExpressionError

  @categories ~w(matching parser tokenizer transformation regex)

  @data_dir Path.join([
              File.cwd!(),
              "test",
              "conformance",
              "cucumber_expressions",
              "data"
            ])

  @doc "The list of conformance categories, in display order."
  def categories, do: @categories

  @doc "Loads all `{name, case_map}` tuples for a category."
  @spec load(String.t()) :: [{String.t(), map()}]
  def load(category) do
    dir = Path.join(@data_dir, category)

    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, ".json"))
    |> Enum.sort()
    |> Enum.map(fn file ->
      name = Path.basename(file, ".json")
      data = file |> then(&Path.join(dir, &1)) |> File.read!() |> JSON.decode!()
      {name, data}
    end)
  end

  @doc """
  Grades every case in a category. Returns `{passed, total, failures}` where
  `failures` is a list of `{name, reason}`.
  """
  @spec grade(String.t()) :: {non_neg_integer(), non_neg_integer(), [{String.t(), term()}]}
  def grade(category) do
    cases = load(category)

    failures =
      cases
      |> Enum.map(fn {name, data} -> {name, grade_case(category, data)} end)
      |> Enum.filter(fn {_name, result} -> result != :ok end)
      |> Enum.map(fn {name, {:fail, reason}} -> {name, reason} end)

    {length(cases) - length(failures), length(cases), failures}
  end

  @doc "Grades a single case map for the given category."
  @spec grade_case(String.t(), map()) :: :ok | {:fail, term()}
  def grade_case("transformation", %{"expression" => expr, "expected_regex" => expected}) do
    actual = CucumberExpression.to_regex(expr, ParameterTypeRegistry.new())
    compare(actual, expected)
  end

  def grade_case("parser", %{"expression" => expr} = data) do
    grade_with_exception(data, fn -> Parser.parse(expr) end, &compare(&1, data["expected_ast"]))
  end

  def grade_case("tokenizer", %{"expression" => expr} = data) do
    grade_with_exception(
      data,
      fn -> Tokenizer.tokenize(expr) end,
      &compare(&1, data["expected_tokens"])
    )
  end

  def grade_case("matching", %{"expression" => expr, "text" => text} = data) do
    grade_with_exception(
      data,
      fn ->
        registry = ParameterTypeRegistry.new()
        compiled = CucumberExpression.compile(expr, registry)
        CucumberExpression.match(compiled, text)
      end,
      fn args -> compare_args(args, data["expected_args"]) end
    )
  end

  # Some matching cases describe a malformed expression with no `text` (they only
  # assert the compile-time exception). Compile and expect the raise.
  def grade_case("matching", %{"expression" => expr} = data) do
    grade_with_exception(
      data,
      fn -> CucumberExpression.compile(expr, ParameterTypeRegistry.new()) end,
      fn _ -> :ok end
    )
  end

  def grade_case("regex", %{"expression" => expr, "text" => text} = data) do
    # Regular-expression matching goes through the same TreeRegexp group machinery
    # as cucumber expressions, so non-participating optional groups come back as
    # `nil` (not `""`), matching the reference behaviour.
    tree = Cabbage.CucumberExpression.TreeRegexp.new(expr)

    case Cabbage.CucumberExpression.TreeRegexp.match(tree, text) do
      nil ->
        compare_args(nil, data["expected_args"])

      group ->
        values = Enum.map(group.children || [], & &1.value)
        compare_args(values, data["expected_args"])
    end
  end

  # ---- helpers ---------------------------------------------------------------

  # Runs `fun`. When the case expects an exception, compares the raised message;
  # otherwise compares the success value via `on_success`.
  defp grade_with_exception(%{"exception" => expected_message}, fun, _on_success) do
    fun.()
    {:fail, {:expected_exception, expected_message}}
  rescue
    e in CucumberExpressionError -> compare(e.message, expected_message)
  end

  defp grade_with_exception(_data, fun, on_success) do
    on_success.(fun.())
  rescue
    e in CucumberExpressionError -> {:fail, {:unexpected_exception, e.message}}
  end

  defp compare(actual, expected) when actual == expected, do: :ok
  defp compare(actual, expected), do: {:fail, {:mismatch, expected: expected, got: actual}}

  # Matching args: `nil` means no-match. Numbers in expected JSON may come back as
  # integers/floats; compare structurally after normalising.
  defp compare_args(nil, nil), do: :ok
  defp compare_args(nil, expected), do: {:fail, {:no_match, expected: expected}}
  defp compare_args(_actual, nil), do: {:fail, :unexpected_match}

  defp compare_args(actual, expected) do
    if normalise_args(actual) == normalise_args(expected) do
      :ok
    else
      {:fail, {:args_mismatch, expected: expected, got: actual}}
    end
  end

  defp normalise_args(args) when is_list(args), do: Enum.map(args, &normalise_arg/1)
  defp normalise_args(other), do: other

  # The testdata encodes ints/floats as JSON numbers, but big integers as JSON
  # strings (since JSON has no bignum). The `{biginteger}` transform returns an
  # exact Elixir integer, so a purely-numeric expected-string is parsed back to
  # an integer for an exact comparison.
  defp normalise_arg(v) when is_binary(v) do
    case Integer.parse(v) do
      {int, ""} -> int
      _ -> v
    end
  end

  defp normalise_arg(v), do: v
end
