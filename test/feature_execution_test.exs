Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureExecutionTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "Tests execution" do
    test "ignores steps that doesn't comply to pattern {:ok, map}" do
      defmodule FeatureExecutionTest do
        use Cabbage.Feature, file: "simple.feature"

        setup do
          {:ok, %{state: [:initial]}}
        end

        defgiven ~r/^I provide Given$/, _vars, %{state: state} do
          [:given | state]
        end

        defgiven ~r/^I provide And$/, _vars, %{state: state} do
          assert [:initial] == state
          nil
        end

        defwhen ~r/^I provide When$/, _vars, %{state: state} do
          assert [:initial] == state
          :ok
        end

        defthen ~r/^I provide Then$/, _vars, %{state: state} do
          assert state == [:initial]
        end
      end

      ExUnit.Server.modules_loaded()
      assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end

    test "error on returning {:ok, not a map}" do
      defmodule FeatureExecutionTest2 do
        use Cabbage.Feature, file: "simple.feature"

        defgiven ~r/^I provide Given$/, _vars, _state do
          {:ok, [some: :some]}
        end

        defgiven ~r/^I provide And$/, _vars, _state do
        end

        defwhen ~r/^I provide When$/, _vars, _state do
        end

        defthen ~r/^I provide Then$/, _vars, _state do
        end
      end

      ExUnit.Server.modules_loaded()
      assert capture_io(fn -> ExUnit.run() end) =~ "** (BadMapError) expected a map, got: [some: :some]"
    end

    test "accepts steps that does comply to pattern {:ok, map}" do
      defmodule FeatureExecutionTest1 do
        use Cabbage.Feature, file: "simple.feature"

        setup do
          {:ok, %{state: [:initial]}}
        end

        defgiven ~r/^I provide Given$/, _vars, %{state: state} do
          {:ok, %{state: [:given | state]}}
        end

        defgiven ~r/^I provide And$/, _vars, %{state: state} do
          {:ok, %{state: [:given | state]}}
        end

        defwhen ~r/^I provide When$/, _vars, %{state: state} do
          {:ok, %{state: [:when | state]}}
        end

        defthen ~r/^I provide Then$/, _vars, %{state: state} do
          assert state == [:when, :given, :given, :initial]
        end
      end

      ExUnit.Server.modules_loaded()
      assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end
  end
end
