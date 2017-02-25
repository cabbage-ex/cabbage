defmodule MissingStepAdvisorTest do
  use ExUnit.Case, async: true

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

    assert_correct_message(step_text, step_type, expected_message)
  end

  test "convert double quote strings to regex capture group in message" do
    step_text = "my name is \"Miran\""
    step_type = "Given"
    expected_message = """
    Please add a matching step for:
    "Given my name is "Miran""

      defgiven ~r/^my name is "(?<string>[^"]+)"$/, vars, state do
        # Your implementation here
      end
    """
    assert_correct_message(step_text, step_type, expected_message)
  end

  test "convert single quote strings to regex capture group in message" do
    step_text = "my name is 'Miran'"
    step_type = "Given"
    expected_message = """
    Please add a matching step for:
    "Given my name is 'Miran'"

      defgiven ~r/^my name is '(?<string>[^']+)'$/, vars, state do
        # Your implementation here
      end
    """

    assert_correct_message(step_text, step_type, expected_message)
  end

  test "convert numbers to regex capture group in message" do
    step_text = "I am 49 years old"
    step_type = "And"
    expected_message = """
    Please add a matching step for:
    "And I am 49 years old"

      defand ~r/^I am (?<number>\\d+) years old$/, vars, state do
        # Your implementation here
      end
    """

    assert_correct_message(step_text, step_type, expected_message)
  end

  test "converting numbers to regex capture group ignores numbers with letters" do
    step_text = "the 3rd number is 1101"
    step_type = "When"
    expected_message = """
    Please add a matching step for:
    "When the 3rd number is 1101"

      defwhen ~r/^the 3rd number is (?<number>\\d+)$/, vars, state do
        # Your implementation here
      end
    """

    assert_correct_message(step_text, step_type, expected_message)
  end

  defp assert_correct_message(step_text, step_type, expected_message) do
    assert_raise(MissingStepError,
                 expected_message,
                 fn ->
                   raise MissingStepError, [step_text: step_text, step_type: step_type]
                 end)
  end
end
