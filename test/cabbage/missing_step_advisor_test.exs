defmodule Cabbage.MissingStepAdvisorTest do
  use ExUnit.Case, async: true

  alias Cabbage.MissingStepAdvisor, as: Sut

  test "raises RuntimeError if step is missing" do
    step_text = "I am Bob"
    step_type = "Given"
    expected_message = """
    Please add a matching step for:
    "Given I am Bob"

      defgiven ~r/^I am Bob$/, vars, state do
        # Your implementation here
      end
    """

    assert_raise(RuntimeError,
                 expected_message,
                 fn -> Sut.raise(step_text, step_type) end)
  end

  test "convert numbers to regex capture group in message" do
    step_text = "I am 49 years old"
    step_type = "And"
    expected_message = """
    Please add a matching step for:
    "And I am 49 years old"

      defand ~r/^I am (?<number>\d+) years old$/, vars, state do
        # Your implementation here
      end
    """

    assert_raise(RuntimeError,
                 expected_message,
                 fn -> Sut.raise(step_text, step_type) end)
  end

  test "converting numbers to regex capture group ignores numbers with letters" do
    step_text = "the 3rd number is 1101"
    step_type = "When"
    expected_message = """
    Please add a matching step for:
    "When the 3rd number is 1101"

      defwhen ~r/^the 3rd number is (?<number>\d+)$/, vars, state do
        # Your implementation here
      end
    """

    assert_raise(RuntimeError,
                 expected_message,
                 fn -> Sut.raise(step_text, step_type) end)
  end
end
