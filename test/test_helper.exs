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

  def run(filters, cases) do
    Enum.each(cases, &ExUnit.Server.add_sync_module/1)

    System.version()
    |> Version.compare("1.6.0")
    |> case do
      :lt -> ExUnit.Server.cases_loaded()
      _ -> ExUnit.Server.modules_loaded()
    end

    opts =
      ExUnit.configuration()
      |> Keyword.merge(filters)
      |> Keyword.merge(colors: [enabled: false])

    output = capture_io(fn -> Process.put(:capture_result, ExUnit.Runner.run(opts, nil)) end)
    {Process.get(:capture_result), output}
  end
end
