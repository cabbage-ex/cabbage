Logger.configure_backend(:console, colors: [enabled: false])
ExUnit.start(trace: "--trace" in System.argv())

# Beam files compiled on demand
path = Path.expand("../tmp/beams", __DIR__)
File.rm_rf!(path)
File.mkdir_p!(path)
Code.prepend_path(path)

defmodule CabbageTestHelper do
  import ExUnit.CaptureIO

  def run(filters \\ [], cases \\ [])

  def run(filters, module) do
    {add_module, load_module} = versioned_callbacks()

    Enum.each(module, add_module)
    load_module.()

    opts =
      ExUnit.configuration()
      |> Keyword.merge(filters)
      |> Keyword.merge(colors: [enabled: false])

    output = capture_io(fn -> Process.put(:capture_result, ExUnit.Runner.run(opts, nil)) end)
    {Map.merge(%{excluded: 0}, Process.get(:capture_result)), output}
  end

  defp versioned_callbacks() do
    System.version()
    |> Version.compare("1.6.0")
    |> case do
      :lt -> {&ExUnit.Server.add_sync_case/1, &ExUnit.Server.cases_loaded/0}
      _ -> {&ExUnit.Server.add_sync_module/1, &ExUnit.Server.modules_loaded/0}
    end
  end
end
