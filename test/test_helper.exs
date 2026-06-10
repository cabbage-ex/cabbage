Logger.configure_backend(:console, colors: [enabled: false])

# The conformance suites (tag :conformance) are excluded from the default
# `mix test` run so it stays fast and green. Run them with `mix conformance`
# (or the richer `mix conformance.tags` / `mix conformance.expressions`
# scoreboards), or `mix test --only conformance`.
ExUnit.start(trace: "--trace" in System.argv(), exclude: [:conformance])

# Beam files compiled on demand
path = Path.expand("../tmp/beams", __DIR__)
File.rm_rf!(path)
File.mkdir_p!(path)
Code.prepend_path(path)

defmodule CabbageTestHelper do
  import ExUnit.CaptureIO

  def run(filters \\ [], modules \\ [])

  def run(filters, modules) do
    {add_module, load_module, result_fix} = versioned_callbacks()

    Enum.each(modules, add_module)
    load_module.()

    opts =
      ExUnit.configuration()
      |> Keyword.merge(filters)
      |> Keyword.merge(colors: [enabled: false])

    output = capture_io(fn -> Process.put(:capture_result, ExUnit.Runner.run(opts, nil)) end)
    {result_fix.(Process.get(:capture_result)), output}
  end

  defp versioned_callbacks() do
    {resolve_add_module(), resolve_load_modules(), resolve_result_fix()}
  end

  defp resolve_add_module() do
    cond do
      function_exported?(ExUnit.Server, :add_module, 2) ->
        fn mod ->
          apply(ExUnit.Server, :add_module, [mod, %{async?: false, group: nil, parameterize: nil}])
        end

      function_exported?(ExUnit.Server, :add_sync_module, 1) ->
        &apply(ExUnit.Server, :add_sync_module, [&1])

      true ->
        &apply(ExUnit.Server, :add_sync_case, [&1])
    end
  end

  defp resolve_load_modules() do
    if function_exported?(ExUnit.Server, :modules_loaded, 1) do
      fn -> apply(ExUnit.Server, :modules_loaded, [true]) end
    else
      fn -> apply(ExUnit.Server, :modules_loaded, []) end
    end
  end

  defp resolve_result_fix() do
    version = Version.parse!(System.version())

    cond do
      Version.match?(version, ">= 1.17.0") -> &normalize_runner_result/1
      Version.match?(version, ">= 1.13.0") -> & &1
      true -> fn result -> Map.merge(result, %{excluded: Map.get(result, :skipped, 0), skipped: 0}) end
    end
  end

  # Elixir 1.17+ changed `ExUnit.Runner.run/2` to return `{result, _}`.
  defp normalize_runner_result({result, _}), do: result
  defp normalize_runner_result(result), do: result
end
