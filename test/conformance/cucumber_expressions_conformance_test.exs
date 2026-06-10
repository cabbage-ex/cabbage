defmodule Cabbage.Conformance.CucumberExpressionsTest do
  @moduledoc """
  Drives the official, language-neutral Cucumber Expressions test suite against
  the engine and asserts a per-category score.

  Tagged `:conformance` so it is excluded from the default `mix test` run (which
  must stay green). Run it with `mix conformance` or
  `mix test --only conformance`. The plain scoreboard is also available as
  `mix conformance.expressions`.
  """
  use ExUnit.Case, async: true

  @moduletag :conformance

  alias Cabbage.Conformance.CucumberExpressions, as: Grader

  # The engine is fully conformant against the vendored testdata (commit
  # 0555a711). Each category asserts the exact pass count so a regression in any
  # area fails loudly rather than silently lowering the score.
  @expected %{
    "matching" => 62,
    "parser" => 27,
    "tokenizer" => 15,
    "transformation" => 8,
    "regex" => 3
  }

  for category <- Grader.categories() do
    test "conformance: #{category}" do
      category = unquote(category)
      {passed, total, failures} = Grader.grade(category)

      assert failures == [],
             "#{category}: #{passed}/#{total} passed. Failures:\n" <>
               Enum.map_join(failures, "\n", fn {name, reason} ->
                 "  - #{name}: #{inspect(reason, limit: :infinity)}"
               end)

      assert passed == @expected[category]
      assert passed == total
    end
  end
end
