defmodule Mix.Tasks.Conformance.Cck do
  @shortdoc "Grades the message-emitting runner against the Cucumber Compatibility Kit"

  @moduledoc """
  Runs the message-emitting runner (`Cabbage.Messages`) over the vendored Cucumber
  Compatibility Kit samples and prints a scoreboard, e.g.

      CCK: 15/44

  For each *targeted* sample it parses the `.feature`, runs the Elixir step definitions,
  normalizes both the produced and golden envelope streams, and compares them. Deferred
  CCK areas (hooks, attachments, parameter-types, retry, ...) are listed as `unsupported`
  so they neither pass nor crash the run.

  Pass `--verbose` to print the first diverging envelope for each failing sample.

  Must run in `:test` (the vendored corpus + harness live under `test/`); `def cli/0` in
  `mix.exs` declares the preferred env so plain `mix conformance.cck` works.
  """

  use Mix.Task

  @requirements ["app.config"]

  # All 44 CCK areas, so the scoreboard denominator reflects the full kit.
  @all_areas ~w(
    all-statuses ambiguous attachments backgrounds cdata data-tables doc-strings empty
    examples-tables examples-tables-attachment examples-tables-undefined failedish-combinations
    global-hooks global-hooks-afterall-error global-hooks-attachments global-hooks-beforeall-error
    hooks hooks-attachment hooks-conditional hooks-named hooks-skipped hooks-undefined markdown
    minimal multiple-features multiple-features-reversed parameter-types pending pending-exception
    regular-expression retry retry-ambiguous retry-pending retry-undefined rules rules-backgrounds
    skipped skipped-exception skipped-failing-hook stack-traces test-run-exception undefined
    unknown-parameter-type unused-steps
  )

  # Why each not-yet-targeted area is deferred. Hook/attachment/param-type/retry/regex
  # areas await their own waves; `test-run-exception` is intentionally *not* graded as a
  # normal run (its golden asserts a run-level crash, mirroring cucumber-js marking it
  # UNSUPPORTED in its own CCK harness).
  @deferral_reasons %{
    "test-run-exception" => "asserts a run-level crash, not a normal gradeable run"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [verbose: :boolean])
    verbose? = Keyword.get(opts, :verbose, false)

    runner = ensure_loaded()

    targeted = apply(runner, :samples, [])
    deferred = @all_areas -- targeted

    results = Enum.map(targeted, fn sample -> {sample, apply(runner, :compare, [sample])} end)

    passed = Enum.count(results, fn {_s, r} -> match?({:ok, _}, r) end)

    Mix.shell().info("CCK: #{passed}/#{length(@all_areas)}")
    Mix.shell().info("  targeted: #{length(targeted)}, passed: #{passed}, deferred: #{length(deferred)}")

    Enum.each(results, fn {sample, result} ->
      Mix.shell().info("  #{status_mark(result)} #{sample}#{detail(result, verbose?)}")
    end)

    Mix.shell().info("  unsupported (deferred): #{Enum.join(deferred, ", ")}")

    Enum.each(@deferral_reasons, fn {area, reason} ->
      if area in deferred, do: Mix.shell().info("    - #{area}: #{reason}")
    end)

    :ok
  end

  # The harness lives under test/conformance/cck and is compiled in :test; load from source
  # otherwise (mirrors conformance.expressions). Steps must load before the runner.
  defp ensure_loaded do
    runner = Cabbage.Conformance.CCK.Runner

    unless Code.ensure_loaded?(runner) do
      Code.require_file("test/conformance/cck/steps.ex")
      Code.require_file("test/conformance/cck/runner.ex")
    end

    runner
  end

  defp status_mark({:ok, _}), do: "PASS"
  defp status_mark({:error, _}), do: "FAIL"

  defp detail({:ok, count}, _verbose), do: " (#{count} envelopes)"
  defp detail({:error, _reason}, false), do: ""

  defp detail({:error, reason}, true) do
    first_line = reason |> String.split("\n") |> hd()
    "\n      " <> first_line
  end
end
