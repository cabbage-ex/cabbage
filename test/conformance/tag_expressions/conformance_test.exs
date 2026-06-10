defmodule Cabbage.TagExpression.ConformanceTest do
  @moduledoc """
  Drives `Cabbage.TagExpression.Conformance` against the vendored upstream corpus
  and asserts full parity. Tagged `:conformance` so it is excluded from the
  default `mix test` (see `test/test_helper.exs`); run it with:

      mix conformance.tags     # scoreboard task (preferred)
      mix conformance          # alias for `mix test --only conformance`
      mix test --only conformance
  """

  use ExUnit.Case, async: true

  @moduletag :conformance

  alias Cabbage.TagExpression.Conformance

  setup_all do
    %{results: Conformance.run()}
  end

  test "parsing corpus round-trips at 100%", %{results: results} do
    {tally, failures} = results.parsing
    assert failures == [], "parsing failures: #{inspect(failures, pretty: true)}"
    assert tally.fail == 0
    assert tally.pass == tally.total
  end

  test "evaluations corpus is fully correct", %{results: results} do
    {tally, failures} = results.evaluations
    assert failures == [], "evaluation failures: #{inspect(failures, pretty: true)}"
    assert tally.fail == 0
    assert tally.pass == tally.total
  end

  test "errors corpus matches reference wording verbatim", %{results: results} do
    {tally, failures} = results.errors
    assert failures == [], "error-message mismatches: #{inspect(failures, pretty: true)}"
    assert tally.fail == 0
    assert tally.pass == tally.total
  end
end
