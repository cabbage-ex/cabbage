Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureTimeoutTest do
  use ExUnit.Case

  describe "Scenarios can provide custom timeout" do
    test "scenario that takes too long stops executing" do
      defmodule FeatureTimeoutTest do
        use Cabbage.Feature, file: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          Process.sleep(:infinity)
        end
      end

      {result, output} = CabbageTestHelper.run(timeout: 10)
      assert result == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      assert output =~ ~r"\*\* \(ExUnit.TimeoutError\) \w+ timed out after \d+ms"
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

      {result, _output} = CabbageTestHelper.run(timeout: 10)
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end
  end
end
