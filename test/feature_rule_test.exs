Code.require_file("test_helper.exs", __DIR__)

 defmodule Cabbage.FeatureRuleTest do
  use ExUnit.Case

   describe "Rules share a common background, but can also stack their own on" do
    test "Checks that Background was properly run" do
      defmodule FeatureRuleTest do
        use Cabbage.Feature, file: "rule.feature"

         defgiven ~r/^I provide Background$/, _vars, _state do
          {:ok, %{background: true}}
        end

         defgiven ~r/^I provide additional Background$/, _vars, %{background: _background} = _state do
          {:ok, %{additional_background: true}}
        end

         defthen ~r/^I provided Background$/, _vars, %{background: background} = _state do
          assert background
        end

         defthen ~r/^I provided additional Background$/, _vars, %{additional_background: background} = _state do
          assert background
        end
      end

       {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 2, excluded: 0}
    end
  end
end
