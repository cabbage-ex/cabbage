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
      capture_io(fn -> assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0} end)
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

    test "accepts state steps that does comply to pattern {:ok, map}" do
      defmodule FeatureExecutionTest3 do
        use Cabbage.Feature, file: "simple.feature"

        setup do
          {:ok, %{state: [:initial]}}
        end

        defgiven ~r/^I provide Given$/, _vars, %{state: state} do
          assert [:initial] == state
          {:ok, %{state: [:given | state]}}
        end

        defgiven ~r/^I provide And$/, _vars, %{state: state} do
          assert [:given, :initial] == state
          {:ok, %{state: [:given | state]}}
        end

        defwhen ~r/^I provide When$/, _vars, %{state: state} do
          assert [:given, :given, :initial] == state
          {:ok, %{state: [:when | state]}}
        end

        defthen ~r/^I provide Then$/, _vars, %{state: state} do
          assert state == [:when, :given, :given, :initial]
        end
      end

      ExUnit.Server.modules_loaded()
      capture_io(fn -> assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0} end)
    end
  end

  describe "Tests contains dynamic and outlined data" do
    test "dynamic patternmatched data are passed to steps" do
      defmodule FeatureExecutionTest4 do
        use Cabbage.Feature, file: "dynamic.feature"

        defgiven ~r/^I provide Given with \"(?<string_1>[^\"]+)\" part$/, %{string_1: string_1}, _state do
          assert string_1 == "given dynamic"
        end

        defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
                %{string_1: string_1, string_2: string_2},
                _state do
          assert string_1 == "when dynamic"
          assert string_2 == "another when dynamic"
        end

        defthen ~r/^I provide Then with \"(?<string_1>[^\"]+)\" part and with docs part$/,
                %{string_1: string_1, doc_string: doc_string},
                _state do
          complex_string = """
          Here is provided some complex part that is way to complex
          """

          assert string_1 == "then dynamic"
          assert doc_string == complex_string
        end

        defthen ~r/^I provide And with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part and with docs part$/,
                %{string_1: string_1, string_2: string_2, table: table},
                _state do
          assert string_1 == "and dynamic"
          assert string_2 == "another and dynamic"

          assert table == [%{Age: "30", Name: "John"}, %{Age: "29", Name: "Ann"}]
        end
      end

      ExUnit.Server.modules_loaded()
      capture_io(fn -> assert ExUnit.run() == %{failures: 0, skipped: 0, total: 1, excluded: 0} end)
    end

    test "outlined data are passed to steps" do
      defmodule FeatureExecutionTest5 do
        use Cabbage.Feature, file: "outline.feature"

        setup do
          datatable = %{
            "a" => "b",
            "c" => "d",
            "e" => "f",
            2 => 3,
            3 => 5,
            5 => 8
          }

          {:ok, %{datatable: datatable}}
        end

        defgiven ~r/^there is given (?<string_1>[^\" ]+) value$/, %{string_1: string_1}, %{datatable: datatable} do
          assert string_1 in Map.keys(datatable)
          {:ok, %{given_value: string_1}}
        end

        defgiven ~r/^there is given numeric (?<number_1>\d+) value$/, %{number_1: number_1}, %{datatable: datatable} do
          number_1 = String.to_integer(number_1)
          assert number_1 in Map.keys(datatable)
          {:ok, %{given_value: number_1}}
        end

        defwhen ~r/^there is when (?<string_1>[^\" ]+) value$/, %{string_1: string_1}, %{
          datatable: datatable,
          given_value: given
        } do
          assert string_1 == Map.get(datatable, given)
          {:ok, %{when_value: string_1}}
        end

        defwhen ~r/^there is when numeric (?<number_1>\d+) value$/, %{number_1: number_1}, %{
          datatable: datatable,
          given_value: given
        } do
          number_1 = String.to_integer(number_1)
          assert number_1 == Map.get(datatable, given)
          {:ok, %{when_value: number_1}}
        end

        defthen ~r/^there is then (?<string_1>[^\" ]+) value$/, %{string_1: string_1}, %{
          given_value: given_value,
          when_value: when_value
        } do
          assert string_1 == given_value <> when_value
        end

        defthen ~r/^there is then numeric (?<number_1>\d+) value$/, %{number_1: number_1}, %{
          given_value: given_value,
          when_value: when_value
        } do
          number_1 = String.to_integer(number_1)
          assert number_1 == given_value + when_value
        end
      end

      ExUnit.Server.modules_loaded()
      capture_io(fn -> assert ExUnit.run() == %{failures: 0, skipped: 0, total: 6, excluded: 0} end)
    end
  end
end
