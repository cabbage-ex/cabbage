defmodule MissingStepAdvisorTest do
  use ExUnit.Case, async: true

  test "raises RuntimeError if step is missing" do
    step_text = "I am Bob"
    step_type = "Given"
    expected_message = """
    Please add a matching step for:
    "Given I am Bob"

      defgiven ~r/^I am Bob$/, _vars, state do
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

      defgiven ~r/^my name is "(?<string_1>[^"]+)"$/, %{string_1: string_1}, state do
        # Your implementation here
      end
    """
    assert_correct_message(step_text, step_type, expected_message)
  end

  test "convert multiple double quote strings" do
    step_text = "my first name is \"Erol\" and my nickname is \"Hungry Homer\""
    step_type = "Given"
    expected_message = """
    Please add a matching step for:
    "Given my first name is "Erol" and my nickname is "Hungry Homer""

      defgiven ~r/^my first name is "(?<string_1>[^"]+)" and my nickname is "(?<string_2>[^"]+)"$/, %{string_1: string_1, string_2: string_2}, state do
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

      defgiven ~r/^my name is '(?<string_1>[^']+)'$/, %{string_1: string_1}, state do
        # Your implementation here
      end
    """

    assert_correct_message(step_text, step_type, expected_message)
  end

  test "convert multiple single quote strings" do
    step_text = "my favourite food & drink is 'Cheese' and 'Liquid Cheese'"
    step_type = "And"
    expected_message = """
    Please add a matching step for:
    "And my favourite food & drink is 'Cheese' and 'Liquid Cheese'"

      defand ~r/^my favourite food & drink is '(?<string_1>[^']+)' and '(?<string_2>[^']+)'$/, %{string_1: string_1, string_2: string_2}, state do
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

      defand ~r/^I am (?<number_1>\\d+) years old$/, %{number_1: number_1}, state do
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

      defwhen ~r/^the 3rd number is (?<number_1>\\d+)$/, %{number_1: number_1}, state do
        # Your implementation here
      end
    """

    assert_correct_message(step_text, step_type, expected_message)
  end

  test "convert numbers to capture group where number is at the beginning" do
    step_text = "29 is my favourite number"
    step_type = "Given"
    expected_message = """
    Please add a matching step for:
    "Given 29 is my favourite number"

      defgiven ~r/^(?<number_1>\\d+) is my favourite number$/, %{number_1: number_1}, state do
        # Your implementation here
      end
    """

    assert_correct_message(step_text, step_type, expected_message)
  end

  test "convert multiple numbers to capture groups" do
    step_text = "there are 3 on the left and 2 on the right"
    step_type = "And"
    expected_message = """
    Please add a matching step for:
    "And there are 3 on the left and 2 on the right"

      defand ~r/^there are (?<number_1>\\d+) on the left and (?<number_2>\\d+) on the right$/, %{number_1: number_1, number_2: number_2}, state do
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
