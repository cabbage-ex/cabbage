Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureTimeoutTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "Scenarios can provide custom timeout" do
    test "scenario that takes too long stops executing" do
      defmodule FeatureTimeoutTest do
        use Cabbage.Feature, file: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          Process.sleep(:infinity)
        end
      end

      ExUnit.configure(timeout: 10)
      ExUnit.Server.modules_loaded()
      output = capture_io(fn -> assert ExUnit.run() == %{failures: 1, skipped: 0, total: 1, excluded: 0} end)
      assert output =~ "** (ExUnit.TimeoutError) test timed out after 10ms"
      assert output =~ ~r"\(elixir\) lib/process\.ex:\d+: Process\.sleep/1"
    end

    test "scenario with custom timeout can execute longer than default limit" do
      defmodule FeatureTimeoutTest1 do
        use Cabbage.Feature, file: "timeout.feature"

        defwhen ~r/^scenario is longer than usual$/, _vars, _state do
          # Your implementation here
        end

        defthen ~r/^it still should be executable$/, _vars, _state do
          Process.sleep(50)
        end
      end

      ExUnit.configure(timeout: 10)
      ExUnit.Server.modules_loaded()
      capture_io(fn -> assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0} end)
    end
  end
end
