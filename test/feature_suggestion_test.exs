Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureSuggestionTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  describe "Incomplete tests" do
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

    test "Show missing And step" do
      message = """
      Please add a matching step for:
      "And I provide And"

        defand ~r/^I provide And$/, _vars, state do
          # Your implementation here
        end
      """

      assert_raise MissingStepError, message, fn ->
        defmodule SampleTest do
          use Cabbage.Feature, file: "simple.feature"

          defgiven ~r/^I provide Given$/, _vars, state do
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
        defmodule SampleTest do
          use Cabbage.Feature, file: "simple.feature"

          defgiven ~r/^I provide Given$/, _vars, state do
            # Your implementation here
          end

          defgiven ~r/^I provide And$/, _vars, state do
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

          defgiven ~r/^I provide Given$/, _vars, state do
            # Your implementation here
          end

          defgiven ~r/^I provide And$/, _vars, state do
            # Your implementation here
          end

          defwhen ~r/^I provide When$/, _vars, state do
            # Your implementation here
          end
        end
      end
    end

    test "Doesnt suggest any features" do
      defmodule SampleTest do
        use Cabbage.Feature, file: "simple.feature"

        defgiven ~r/^I provide Given$/, _vars, state do
          # Your implementation here
        end

        defgiven ~r/^I provide And$/, _vars, state do
          # Your implementation here
        end

        defwhen ~r/^I provide When$/, _vars, state do
          # Your implementation here
        end

        defthen ~r/^I provide Then$/, _vars, state do
          # Your implementation here
        end
      end
    end
  end
end
