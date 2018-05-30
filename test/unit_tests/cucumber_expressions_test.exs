defmodule Cabbage.Feature.CucumberExpressionsTest do
  use ExUnit.Case
  alias Cabbage.Feature.CucumberExpressions

  describe "checking for step definition being implemented" do
    test "step definition is implemented with first argument being string" do
      step_definition = {:{}, [], ["Given some feature step text", {}, {}, {}, %{}]}
      feature_step = "Given some feature step text"
      assert CucumberExpressions.implemented?(feature_step, step_definition)
    end

    test "step definition is not implemented with first argument being string and extra words at the beginning" do
      step_definition = {:{}, [], ["This should not match Given some feature step text", {}, {}, {}, %{}]}
      feature_step = "Given some feature step text"
      refute CucumberExpressions.implemented?(feature_step, step_definition)
    end

    test "step definition is not implemented with first argument being string with extra words at the end" do
      step_definition = {:{}, [], ["Given some feature step text this should not match", {}, {}, {}, %{}]}
      feature_step = "Given some feature step text"
      refute CucumberExpressions.implemented?(feature_step, step_definition)
    end

    test "step definition is implemented with first argument being regex" do
      quoted_regex = quote do: ~r/^Given some feature step text$/
      step_definition = {:{}, [], [quoted_regex, {}, {}, {}, %{}]}
      feature_step = "Given some feature step text"
      assert CucumberExpressions.implemented?(feature_step, step_definition)
    end
  end

  describe "converting to regex" do
    test "quoted regex returns regex" do
      quoted_regex = quote do: ~r/^Given some feature step text$/
      assert CucumberExpressions.to_regex(quoted_regex) == ~r/^Given some feature step text$/
    end

    test "string returns regex" do
      assert CucumberExpressions.to_regex("Given some feature step text") == ~r/^Given some feature step text$/
    end
  end
end
