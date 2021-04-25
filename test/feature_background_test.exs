Code.require_file("test_helper.exs", __DIR__)

 defmodule Cabbage.FeatureBackgroundTest do
  use ExUnit.Case

   describe "Features can have state setup by a Background" do
    test "Checks that Background was properly run" do
      defmodule FeatureBackgroundTest do
        use Cabbage.Feature, file: "background.feature"

         defgiven ~r/^I provide Background$/, _vars, _state do
          {:ok, %{background: true}}
        end

         defthen ~r/^I provided Background$/, _vars, %{background: background} = _state do
          assert background
        end
      end

       {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 2, excluded: 0}
    end
  end
end
