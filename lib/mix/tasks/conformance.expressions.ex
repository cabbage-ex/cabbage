defmodule Mix.Tasks.Conformance.Expressions do
  @shortdoc "Grades the Cucumber Expressions engine against the official testdata"

  @moduledoc """
  Runs the vendored Cucumber Expressions conformance suite and prints a
  per-category scoreboard, e.g.

      Expressions: matching 60/62, parser 27/27, tokenizer 15/15, transformation 8/8, regex 3/3

  Pass `--verbose` to also list every failing case and why it failed.

  This task must run in the `:test` environment because the grader lives under
  `test/support`. `def cli/0` in `mix.exs` declares the preferred env so plain
  `mix conformance.expressions` works without a warning.
  """

  use Mix.Task

  @requirements ["app.config"]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [verbose: :boolean])
    verbose? = Keyword.get(opts, :verbose, false)

    grader = Cabbage.Conformance.CucumberExpressions

    # Ensure the grader (which lives under test/support) is loaded. In :test it
    # is already on the path; otherwise load it from source.
    unless Code.ensure_loaded?(grader) do
      Code.require_file("test/support/conformance/cucumber_expressions.ex")
    end

    # `grader` lives under test/support and is not compiled in non-test envs, so
    # dispatch dynamically to avoid a compile-time "undefined" warning.
    results =
      Enum.map(apply(grader, :categories, []), fn category ->
        {passed, total, failures} = apply(grader, :grade, [category])
        {category, passed, total, failures}
      end)

    summary =
      results
      |> Enum.map(fn {cat, passed, total, _} -> "#{cat} #{passed}/#{total}" end)
      |> Enum.join(", ")

    Mix.shell().info("Expressions: " <> summary)

    if verbose? do
      Enum.each(results, fn {cat, _passed, _total, failures} ->
        Enum.each(failures, fn {name, reason} ->
          Mix.shell().info("  [#{cat}] #{name}: #{inspect(reason, limit: :infinity, printable_limit: :infinity)}")
        end)
      end)
    end

    :ok
  end
end
