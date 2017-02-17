defmodule Cabbage.MissingStepAdvisorTest do
  use ExUnit.Case, async: true

  alias Cabbage.MissingStepAdvisor, as: Sut

  test "raises RuntimeError is step is missing" do
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
end
