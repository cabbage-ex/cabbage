Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureSuggestionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  describe "Incomplete simple tests" do
    test "Show missing Given step" do
      message = """
      Please add a matching step for:
      "Given I provide Given"

        defgiven ~r/^I provide Given$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule SampleTest do
          use Cabbage.Feature, file: "simple.feature"
        end
      end
    end

    @doc """
    TODO: Doesn't suggest correct part line.
    defand shouldn't even exist
    As i understand defgive, defwhen, defthen and defand all work exaclty the same and there even isn't any difference between them.
    """
    # test "Show missing And step" do
    #   message = """
    #   Please add a matching step for:
    #   "And I provide And"
    #
    #     defgiven ~r/^I provide And$/, _vars, state do
    #       # Your implementation here
    #     end
    #   """
    #
    #   assert_raise MissingStepError, message, fn ->
    #     defmodule SampleTest do
    #       use Cabbage.Feature, file: "simple.feature"
    #
    #       defgiven ~r/^I provide Given$/, _vars, _state do
    #         # Your implementation here
    #       end
    #     end
    #   end
    # end

    test "Show missing When step" do
      message = """
      Please add a matching step for:
      "When I provide When"

        defwhen ~r/^I provide When$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule SampleTest do
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
        defmodule SampleTest do
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
      defmodule SampleTest do
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

      assert true
    end
  end

  describe "Incomplete dynamic tests" do
    test "Show missing dynamic Given step with one dynamic part" do
      message = """
      Please add a matching step for:
      "Given I provide Given with \"given dynamic\" part"

        defgiven ~r/^I provide Given with \"(?<string_1>[^\"]+)\" part$/, %{string_1: string_1}, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule SampleTest do
          use Cabbage.Feature, file: "dynamic.feature"
        end
      end
    end

    test "Show missing dynamic When step with two dynamic parts" do
      message = """
      Please add a matching step for:
      "When I provide When with \"and dynamic\" part and with one more \"another when dynamic\" part"

        defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/, %{string_1: string_1, string_2: string_2}, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule SampleTest do
          use Cabbage.Feature, file: "dynamic.feature"

          defgiven ~r/^I provide Given with \"(?<string_1>[^\"]+)\" part$/, %{string_1: _string_1}, _state do
            # Your implementation here
          end
        end
      end
    end

    @doc """
    TODO: Sugesting doesn't suggest correct code, if part has extra docs line
    """
    # test "Show missing dynamic Then step with two dynamic parts one of which is docs" do
    #   message = """
    #   Please add a matching step for:
    #   "Then I provide Then with \"when dynamic\" part and with docs part"
    #
    #     defthen ~r/^I provide Then with \"(?<string_1>[^\"]+)\" part and with docs part$/, %{string_1: string_1, doc_string: doc_string}, state do
    #       # Your implementation here
    #     end
    #   """
    #
    #   assert_raise MissingStepError, message, fn ->
    #     defmodule SampleTest do
    #       use Cabbage.Feature, file: "dynamic.feature"
    #
    #       defgiven ~r/^I provide Given with \"(?<string_1>[^\"]+)\" part$/, %{string_1: string_1}, state do
    #         # Your implementation here
    #       end
    #
    #       defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
    #               %{string_1: _string_1, string_2: _string_2},
    #               _state do
    #         # Your implementation here
    #       end
    #     end
    #   end
    # end

    @doc """
    TODO: This test doesn't work because of suggested is `defand` not `defthen`
    TODO: This test doens't work because of missing `doc_string` in `vars`
    """
    # test "Show missing dynamic And step with three dynamic parts one of which is docs" do
    #   message = """
    #   Please add a matching step for:
    #   "And I provide And with \"then dynamic\" part and with one more \"another when dynamic\" part and with docs part"
    #
    #     defthen ~r/^I provide And with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part and with docs part$/, %{string_1: string_1, string_2: string_2, doc_string: doc_string}, state do
    #       # Your implementation here
    #     end
    #   """
    #
    #   assert_raise MissingStepError, message, fn ->
    #     defmodule SampleTest do
    #       use Cabbage.Feature, file: "dynamic.feature"
    #
    #       defgiven ~r/^I provide Given with \"(?<string_1>[^\"]+)\" part$/, %{string_1: _string_1}, _state do
    #         # Your implementation here
    #       end
    #
    #       defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
    #               %{string_1: _string_1, string_2: _string_2},
    #               _state do
    #         # Your implementation here
    #       end
    #
    #       defthen ~r/^I provide Then with \"(?<string_1>[^\"]+)\" part and with docs part$/,
    #               %{string_1: _string_1, doc_string: _doc_string},
    #               _state do
    #         # Your implementation here
    #       end
    #     end
    #   end
    # end

    test "Do not show suggested items if all present" do
      defmodule SampleTest do
        use Cabbage.Feature, file: "dynamic.feature"

        defgiven ~r/^I provide Given with \"(?<string_1>[^\"]+)\" part$/, %{string_1: _string_1}, _state do
          # Your implementation here
        end

        defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
                %{string_1: _string_1, string_2: _string_2},
                _state do
          # Your implementation here
        end

        defthen ~r/^I provide Then with \"(?<string_1>[^\"]+)\" part and with docs part$/,
                %{string_1: _string_1, doc_string: _doc_string},
                _state do
          # Your implementation here
        end

        defthen ~r/^I provide And with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part and with docs part$/,
                %{string_1: _string_1, string_2: _string_2, doc_string: _doc_string},
                _state do
          # Your implementation here
        end
      end

      assert true
    end
  end

  describe "Incomplete outline tests" do
    @doc """
    TODO: Outline values aren't patternmatched to be dynamic when they are strign values
    """
    # test "Show missing dynamic Given step" do
    #   message = """
    #   Please add a matching step for:
    #   "Given there is a value"
    #
    #     defgiven ~r/^there is \"(?<string_1>[^\"]+)\" value$/, %{string_1: string_1}, state do
    #       # Your implementation here
    #     end
    #   """
    #
    #   assert_raise MissingStepError, message, fn ->
    #     defmodule SampleTest do
    #       use Cabbage.Feature, file: "outline.feature"
    #     end
    #   end
    # end
  end
end
