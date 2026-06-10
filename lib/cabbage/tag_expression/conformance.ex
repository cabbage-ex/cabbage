defmodule Cabbage.TagExpression.Conformance do
  @moduledoc """
  Objective parity harness for `Cabbage.TagExpression`, run against the official
  cross-language corpus vendored under `test/conformance/tag_expressions/`
  (see that directory's `UPSTREAM.md` for the commit SHA and provenance).

  Three corpora, mirroring the upstream `testdata/`:

    * **parsing** — parse `expression`, assert `to_string/1 == formatted`, then
      re-parse `formatted` and assert it renders identically (idempotence).
    * **evaluations** — for each sub-case, evaluate the expression against
      `variables` and assert the boolean `result`.
    * **errors** — assert parsing fails with the exact `error` message.

  The harness only depends on the built-in `JSON` module (no `jason`). Both the
  `mix conformance.tags` task and the tagged ExUnit conformance test drive this.
  """

  @data_dir Path.expand("../../../test/conformance/tag_expressions/data", __DIR__)

  alias Cabbage.TagExpression

  @type tally :: %{pass: non_neg_integer(), fail: non_neg_integer(), total: non_neg_integer()}
  @type failure :: %{required: String.t(), optional: term()}

  @doc "Run all three corpora and return `{tally, failures}` keyed by corpus."
  @spec run() :: %{
          parsing: {tally(), [map()]},
          evaluations: {tally(), [map()]},
          errors: {tally(), [map()]}
        }
  def run do
    %{
      parsing: run_parsing(),
      evaluations: run_evaluations(),
      errors: run_errors()
    }
  end

  # --- parsing -------------------------------------------------------------

  defp run_parsing do
    "parsing.json"
    |> load()
    |> grade(fn %{"expression" => expression, "formatted" => formatted} ->
      with {:ok, parsed} <- TagExpression.parse(expression),
           rendered = to_string(parsed),
           true <- rendered == formatted,
           {:ok, reparsed} <- TagExpression.parse(formatted),
           true <- to_string(reparsed) == formatted do
        :pass
      else
        {:error, message} -> {:fail, %{expression: expression, error: message}}
        false -> {:fail, %{expression: expression, expected: formatted}}
      end
    end)
  end

  # --- evaluations ---------------------------------------------------------
  #
  # One "case" per (expression, sub-case) pair so the count reflects every
  # variables/result assertion, not just the expression groups.

  defp run_evaluations do
    "evaluations.json"
    |> load()
    |> Enum.flat_map(fn %{"expression" => expression, "tests" => tests} ->
      Enum.map(tests, fn %{"variables" => variables, "result" => result} ->
        %{"expression" => expression, "variables" => variables, "result" => result}
      end)
    end)
    |> grade(fn %{"expression" => expression, "variables" => variables, "result" => expected} ->
      case TagExpression.parse(expression) do
        {:ok, parsed} ->
          if TagExpression.evaluate(parsed, variables) == expected,
            do: :pass,
            else: {:fail, %{expression: expression, variables: variables, expected: expected}}

        {:error, message} ->
          {:fail, %{expression: expression, error: message}}
      end
    end)
  end

  # --- errors --------------------------------------------------------------

  defp run_errors do
    "errors.json"
    |> load()
    |> grade(fn %{"expression" => expression, "error" => expected} ->
      case TagExpression.parse(expression) do
        {:error, ^expected} ->
          :pass

        {:error, actual} ->
          {:fail, %{expression: expression, expected: expected, got: actual}}

        {:ok, _} ->
          {:fail, %{expression: expression, expected: expected, got: :parsed_ok}}
      end
    end)
  end

  # --- shared --------------------------------------------------------------

  defp grade(cases, fun) do
    results = Enum.map(cases, fun)

    failures = for {:fail, detail} <- results, do: detail
    pass = Enum.count(results, &(&1 == :pass))
    total = length(results)

    {%{pass: pass, fail: total - pass, total: total}, failures}
  end

  defp load(filename) do
    @data_dir
    |> Path.join(filename)
    |> File.read!()
    |> JSON.decode!()
  end
end
