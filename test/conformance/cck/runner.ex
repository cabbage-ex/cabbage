defmodule Cabbage.Conformance.CCK.Runner do
  @moduledoc """
  Drives `Cabbage.Messages` over a vendored CCK sample and compares the produced envelope
  stream against the golden `.ndjson`, after normalization.

  A sample is described by `sample_spec/1`: the feature file(s) (with their `samples/...`
  uris and media format) and the `Cabbage.Conformance.CCK.Steps` registry to run them
  against. `multiple-features-reversed` additionally reverses pickle execution order
  (the upstream `--order reverse` argument). The `retry*` areas carry a `--retry N`
  argument (in `<area>.arguments.txt`) that is parsed and threaded as `:retry`.

  `compare/1` returns `{:ok, count}` on a match or `{:error, diff}` describing the first
  divergence, so the scoreboard can print actionable per-sample failures.
  """

  alias Cabbage.Messages
  alias Cabbage.Messages.Normalizer
  alias Cabbage.Conformance.CCK.Steps

  @data_dir Path.join([__DIR__, "data"])

  # The CCK areas this wave targets. Deferred areas are tracked by the Mix task.
  @samples ~w(
    minimal empty backgrounds data-tables doc-strings cdata rules rules-backgrounds
    examples-tables examples-tables-undefined markdown multiple-features multiple-features-reversed
    unused-steps undefined pending skipped ambiguous
    all-statuses failedish-combinations stack-traces pending-exception skipped-exception
    parameter-types regular-expression unknown-parameter-type
    hooks hooks-named hooks-conditional hooks-skipped hooks-undefined
    global-hooks global-hooks-beforeall-error global-hooks-afterall-error skipped-failing-hook
    attachments examples-tables-attachment hooks-attachment global-hooks-attachments
    retry retry-ambiguous retry-pending retry-undefined
  )

  @doc "The list of CCK sample areas this harness runs."
  @spec samples() :: [String.t()]
  def samples, do: @samples

  @doc "Absolute path to the vendored data directory."
  @spec data_dir() :: String.t()
  def data_dir, do: @data_dir

  @doc """
  Run `sample` and compare to its golden. Returns `{:ok, envelope_count}` or
  `{:error, reason}` where reason is a human-readable description of the first mismatch.
  """
  @spec compare(String.t()) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def compare(sample) do
    actual = run(sample) |> Normalizer.normalize()
    golden = golden(sample) |> Normalizer.normalize()
    diff(actual, golden)
  rescue
    error -> {:error, "raised #{inspect(error.__struct__)}: " <> first_line(Exception.message(error))}
  end

  defp first_line(message), do: message |> String.split("\n") |> hd()

  @doc "The actual envelope stream `Cabbage.Messages` produces for `sample` (un-normalized)."
  @spec run(String.t()) :: [map()]
  def run(sample) do
    %{features: features, reverse: reverse?, retry: retry} = sample_spec(sample)
    registry = Steps.for(sample)
    hooks = Steps.hooks_for(sample)

    run_opts =
      [hooks: hooks]
      |> then(fn opts -> if reverse?, do: [{:order, :reverse} | opts], else: opts end)
      |> then(fn opts -> if retry > 0, do: [{:retry, retry} | opts], else: opts end)

    Messages.run_features(features, registry, run_opts)
  end

  @doc "The golden envelope stream for `sample`, parsed from the vendored `.ndjson`."
  @spec golden(String.t()) :: [map()]
  def golden(sample) do
    [ndjson] = Path.wildcard(Path.join([@data_dir, sample, "*.ndjson"]))

    ndjson
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.map(fn line -> JSON.decode!(line) end)
  end

  # ---- sample specs ----------------------------------------------------------

  defp sample_spec(sample) do
    %{
      features: feature_files(sample),
      reverse: sample == "multiple-features-reversed",
      retry: retry_count(sample)
    }
  end

  # The `--retry N` count from the sample's `<area>.arguments.txt` (0 when absent).
  defp retry_count(sample) do
    case Path.wildcard(Path.join([@data_dir, sample, "*.arguments.txt"])) do
      [path] -> parse_retry(File.read!(path))
      [] -> 0
    end
  end

  defp parse_retry(contents) do
    case Regex.run(~r/--retry\s+(\d+)/, contents) do
      [_, n] -> String.to_integer(n)
      nil -> 0
    end
  end

  # A sample's feature inputs as {source, opts}, in document order, with `samples/...` uris.
  defp feature_files(sample) do
    extension = if sample == "markdown", do: "*.feature.md", else: "*.feature"

    Path.join([@data_dir, sample, extension])
    |> Path.wildcard()
    |> Enum.sort()
    |> Enum.map(fn path ->
      uri = "samples/#{sample}/#{Path.basename(path)}"
      format = if String.ends_with?(path, ".md"), do: :markdown, else: :plain
      {File.read!(path), uri: uri, format: format}
    end)
  end

  # ---- comparison ------------------------------------------------------------

  defp diff(actual, golden) when length(actual) != length(golden) do
    {:error,
     "envelope count mismatch: actual=#{length(actual)} golden=#{length(golden)}\n" <>
       count_summary(actual, golden)}
  end

  defp diff(actual, golden) do
    actual
    |> Enum.zip(golden)
    |> Enum.with_index()
    |> Enum.find_value({:ok, length(actual)}, fn {{a, g}, index} ->
      if a == g do
        false
      else
        {:error,
         "envelope ##{index} (#{envelope_type(a)}) differs:\n  actual: #{JSON.encode!(a)}\n  golden: #{JSON.encode!(g)}"}
      end
    end)
  end

  defp count_summary(actual, golden) do
    "  actual types: #{actual |> Enum.map(&envelope_type/1) |> Enum.join(",")}\n" <>
      "  golden types: #{golden |> Enum.map(&envelope_type/1) |> Enum.join(",")}"
  end

  defp envelope_type(map) when is_map(map), do: map |> Map.keys() |> List.first()
  defp envelope_type(_), do: "?"
end
