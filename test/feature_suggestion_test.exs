Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureSuggestionTest do
  use ExUnit.Case

  describe "provide simple missing steps" do
    test "Show missing Given step" do
      message = """
      Please add a matching step for:
      "Given I provide Given"

        defgiven ~r/^I provide Given$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest do
          use Cabbage.Feature, file: "simple.feature"
        end
      end
    end

    test "Show missing And step" do
      message = """
      Please add a matching step for:
      "Given I provide And"

        defgiven ~r/^I provide And$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest2 do
          use Cabbage.Feature, file: "simple.feature"

          defgiven ~r/^I provide Given$/, _vars, _state do
            # Your implementation here
          end
        end
      end
    end

    test "Show missing When step" do
      message = """
      Please add a matching step for:
      "When I provide When"

        defwhen ~r/^I provide When$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest3 do
          use Cabbage.Feature, file: "simple.feature"

          defgiven ~r/^I provide Given$/, _vars, _state do
            # Your implementation here
          end

          defgiven ~r/^I provide And$/, _vars, _state do
            # Your implementation here
          end
        end
      end
    end

    test "Show missing Then step" do
      message = """
      Please add a matching step for:
      "Then I provide Then"

        defthen ~r/^I provide Then$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest4 do
          use Cabbage.Feature, file: "simple.feature"

          defgiven ~r/^I provide Given$/, _vars, _state do
            # Your implementation here
          end

          defgiven ~r/^I provide And$/, _vars, _state do
            # Your implementation here
          end

          defwhen ~r/^I provide When$/, _vars, _state do
            # Your implementation here
          end
        end
      end
    end

    test "Doesnt suggest any features" do
      defmodule FeatureSuggestionTest5 do
        use Cabbage.Feature, file: "simple.feature"

        defgiven ~r/^I provide Given$/, _vars, _state do
          # Your implementation here
        end

        defgiven ~r/^I provide And$/, _vars, _state do
          # Your implementation here
        end

        defwhen ~r/^I provide When$/, _vars, _state do
          # Your implementation here
        end

        defthen ~r/^I provide Then$/, _vars, _state do
          # Your implementation here
        end
      end

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end
  end

  describe "provide dynamic missing steps" do
    test "Show missing dynamic Given step with one dynamic part" do
      message = """
      Please add a matching step for:
      "Given I provide Given with \'given dynamic\' part"

        defgiven ~r/^I provide Given with \'(?<string_1>[^\']+)\' part$/, %{string_1: string_1}, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest6 do
          use Cabbage.Feature, file: "dynamic.feature"
        end
      end
    end

    test "Show missing dynamic When step with two dynamic parts" do
      message = """
      Please add a matching step for:
      "When I provide When with \"when dynamic\" part and with one more \"another when dynamic\" part"

        defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/, %{string_1: string_1, string_2: string_2}, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest7 do
          use Cabbage.Feature, file: "dynamic.feature"

          defgiven ~r/^I provide Given with \'(?<string_1>[^\']+)\' part$/, %{string_1: _string_1}, _state do
            # Your implementation here
          end
        end
      end
    end

    @doc """
    TODO: Sugesting doesn't suggest correct code, if part has extra docs line
    Missing `doc_string: doc_string` in `_vars`
    """
    test "Show missing dynamic Then step with two dynamic parts one of which is docs" do
      message = """
      Please add a matching step for:
      "Then I provide Then with number 6 part and with docs part\"

        defthen ~r/^I provide Then with number (?<number_1>\d+) part and with docs part$/, %{number_1: number_1}, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest8 do
          use Cabbage.Feature, file: "dynamic.feature"

          defgiven ~r/^I provide Given with \'(?<string_1>[^\']+)\' part$/, %{string_1: string_1}, state do
            # Your implementation here
          end

          defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
                  %{string_1: _string_1, string_2: _string_2},
                  _state do
            # Your implementation here
          end
        end
      end
    end

    @doc """
    TODO: This test doens't work because of missing `doc_string` in `vars`
    """
    test "Show missing dynamic And step with three dynamic parts one of which is docs" do
      message = """
      Please add a matching step for:
      "Then I provide And with \"and dynamic\" part and with one more \"another and dynamic\" part and with docs part"

        defthen ~r/^I provide And with "(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part and with docs part$/, %{string_1: string_1, string_2: string_2}, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest9 do
          use Cabbage.Feature, file: "dynamic.feature"

          defgiven ~r/^I provide Given with \'(?<string_1>[^\']+)\' part$/, %{string_1: _string_1}, _state do
            # Your implementation here
          end

          defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
                  %{string_1: _string_1, string_2: _string_2},
                  _state do
            # Your implementation here
          end

          defthen ~r/^I provide Then with number (?<number_1>\d+) part and with docs part$/,
                  %{number_1: _number_1, doc_string: _doc_string},
                  _state do
            # Your implementation here
          end
        end
      end
    end

    test "Do not show suggested items if all present" do
      defmodule FeatureSuggestionTest10 do
        use Cabbage.Feature, file: "dynamic.feature"

        defgiven ~r/^I provide Given with \'(?<string_1>[^\']+)\' part$/, %{string_1: _string_1}, _state do
          # Your implementation here
        end

        defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
                %{string_1: _string_1, string_2: _string_2},
                _state do
          # Your implementation here
        end

        defthen ~r/^I provide Then with number (?<number_1>\d+) part and with docs part$/,
                %{number_1: _number_1, doc_string: _doc_string},
                _state do
          # Your implementation here
        end

        defthen ~r/^I provide And with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part and with docs part$/,
                %{string_1: _string_1, string_2: _string_2, doc_string: _doc_string},
                _state do
          # Your implementation here
        end
      end

      {result, _output} = CabbageTestHelper.run()
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end
  end

  describe "provide outline missing steps" do
    @doc """
    TODO: Outline values aren't patternmatched to be dynamic when they are strign values
    """
    test "Show missing dynamic Given step" do
      message = """
      Please add a matching step for:
      "Given there is given a value"

        defgiven ~r/^there is given a value$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule FeatureSuggestionTest11 do
          use Cabbage.Feature, file: "outline.feature"
        end
      end
    end
  end
end
