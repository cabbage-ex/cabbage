Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureExecutionTest do
  use ExUnit.Case

  describe "Tests execution" do
    test "ignores steps that doesn't comply to pattern {:ok, map}" do
      defmodule FeatureExecutionTest do
        use Cabbage.Case, feature: "simple.feature"

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

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end

    test "error on returning {:ok, not a map}" do
      defmodule FeatureExecutionTest2 do
        use Cabbage.Case, feature: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          {:ok, [some: :some]}
        end
      end

      {result, output} = CabbageTestHelper.run()
      assert result == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      assert output =~ "** (BadMapError) expected a map, got: [some: :some]"
    end

    test "accepts state steps that does comply to pattern {:ok, map}" do
      defmodule FeatureExecutionTest3 do
        use Cabbage.Case, feature: "simple.feature"

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

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end
  end

  describe "Tests contains dynamic and outlined data" do
    test "dynamic patternmatched data are passed to steps" do
      defmodule FeatureExecutionTest4 do
        use Cabbage.Case, feature: "dynamic.feature"

        defgiven ~r/^I provide Given with \'(?<string_1>[^\']+)\' part$/, %{string_1: string_1}, _state do
          assert string_1 == "given dynamic"
        end

        defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
                %{string_1: string_1, string_2: string_2},
                _state do
          assert string_1 == "when dynamic"
          assert string_2 == "another when dynamic"
        end

        defthen ~r/^I provide Then with number (?<number_1>\d+) part and with docs part$/,
                %{number_1: number_1, doc_string: doc_string},
                _state do
          complex_string = """
          Here is provided some complex part that is way to complex
          """

          # TODO: Shouldn't it be casted to a integer?
          assert number_1 == "6"
          assert doc_string == complex_string
        end

        defthen ~r/^I provide And with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part and with table part$/,
                %{string_1: string_1, string_2: string_2, table: table},
                _state do
          assert string_1 == "and dynamic"
          assert string_2 == "another and dynamic"

          assert table == [%{Age: "30", Name: "John"}, %{Age: "29", Name: "Ann"}]
        end
      end

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end

    test "outlined data are passed to steps" do
      defmodule FeatureExecutionTest5 do
        use Cabbage.Case, feature: "outline.feature"

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

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 6, excluded: 0}
    end
  end

  describe "Tests with background steps" do
    test "background steps are executed" do
      defmodule BackroundFeatureExecutionTest do
        use Cabbage.Case, feature: "background.feature"

        defgiven ~r/^a background step \"(?<string_1>[^\"]+)\" provided$/, %{string_1: string_1}, _state do
          {:ok, %{first_background: string_1}}
        end

        defgiven ~r/^a another step \"(?<string_1>[^\"]+)\" provided$/, %{string_1: string_1}, _state do
          {:ok, %{second_background: string_1}}
        end

        defwhen ~r/^step provided in scenario$/, _vars, _state do
          {:ok, %{regular_step: :regular_step}}
        end

        defwhen ~r/^another step provided in scenario$/, _vars, _state do
          {:ok, %{another_regular_step: :another_regular_step}}
        end

        defthen ~r/^all steps should have been taken into account$/, _vars, %{regular_step: _} = state do
          assert state.first_background == "first step"
          assert state.second_background == "second step"
          assert state.regular_step == :regular_step
        end

        defthen ~r/^all steps should have been taken into account$/, _vars, %{another_regular_step: _} = state do
          assert state.first_background == "first step"
          assert state.second_background == "second step"
          assert state.another_regular_step == :another_regular_step
        end
      end

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 2, excluded: 0}
    end
  end
end
