defmodule Mix.Tasks.Conformance.Tags do
  @shortdoc "Run the Cabbage.TagExpression conformance scoreboard"

  @moduledoc """
  Run the tag-expression engine against the official cross-language conformance
  corpus and print a scoreboard.

      mix conformance.tags

  The corpus is vendored under `test/conformance/tag_expressions/` (see its
  `UPSTREAM.md`). This task is registered with `preferred_envs` so it always runs
  in `:test` — where the data files and `Cabbage.TagExpression.Conformance` are
  available — without the caller needing `MIX_ENV=test`.

  Exits non-zero if any case fails, so CI can gate on 100%.
  """

  use Mix.Task

  alias Cabbage.TagExpression.Conformance

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    %{parsing: {parsing, p_fail}, evaluations: {eval, e_fail}, errors: {errors, err_fail}} =
      Conformance.run()

    line = String.duplicate("=", 64)

    IO.puts("""

    #{line}
     TAG EXPRESSION CONFORMANCE SCOREBOARD  (cucumber/tag-expressions testdata)
    #{line}
     parsing      #{parsing.pass}/#{parsing.total}\tpass=#{parsing.pass} fail=#{parsing.fail}
     evaluations  #{eval.pass}/#{eval.total}\tpass=#{eval.pass} fail=#{eval.fail}
     errors       #{errors.pass}/#{errors.total}\tpass=#{errors.pass} fail=#{errors.fail}
    #{line}
     Tags: parsing #{parsing.pass}/#{parsing.total}, evaluations #{eval.pass}/#{eval.total}, errors #{errors.pass}/#{errors.total}
    #{line}
    """)

    print_failures("parsing", p_fail)
    print_failures("evaluations", e_fail)
    print_failures("errors", err_fail)

    if parsing.fail + eval.fail + errors.fail > 0 do
      Mix.raise("Tag expression conformance incomplete — see failures above.")
    end
  end

  defp print_failures(_corpus, []), do: :ok

  defp print_failures(corpus, failures) do
    IO.puts(" #{corpus} failures:")
    Enum.each(failures, fn failure -> IO.puts("   - #{inspect(failure)}") end)
    IO.puts("")
  end
end
