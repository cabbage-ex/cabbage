defmodule Cabbage.Feature.CucumberExpressionTest do
  use ExUnit.Case, async: true
  alias Cabbage.Feature.CucumberExpression

  describe "converting cucumber expressions to regex" do
    test "convert simple string" do
      expression = "simple string"
      expected_regex_string = ~S/^simple string$/
      assert CucumberExpression.to_regex_string(expression) == expected_regex_string
    end

    test "convert string containing type integer" do
      expression = "{quantity:int} string"
      expected_regex_string = ~S/^(?<quantity>\d+) string$/
      assert CucumberExpression.to_regex_string(expression) == expected_regex_string
    end

    test "convert string containing 2 integer types" do
      expression = "{tea_count:int} tea and {coffee_count:int} coffee"
      expected_regex_string = ~S/^(?<tea_count>\d+) tea and (?<coffee_count>\d+) coffee$/
      assert CucumberExpression.to_regex_string(expression) == expected_regex_string
    end

    test "convert string containing float" do
      expression = "It cost $ {cost:float}"
      expected_regex_string = ~S/^It cost $ (?<cost>\d+\.\d+)$/
      assert CucumberExpression.to_regex_string(expression) == expected_regex_string
    end

    test "convert string containing float and integer" do
      expression = "It cost $ {price:int} or $ {cost:float} to be precise"
      expected_regex_string = ~S/^It cost $ (?<price>\d+) or $ (?<cost>\d+\.\d+) to be precise$/
      assert CucumberExpression.to_regex_string(expression) == expected_regex_string
    end

    test "convert string containing word" do
      expression = "My name is {name:word} I tell you!"
      expected_regex_string = ~S/^My name is (?<name>\w*\S) I tell you!$/
      assert CucumberExpression.to_regex_string(expression) == expected_regex_string
    end

    test "convert string containing string" do
      expression = "My full name is {full_name:string} I tell you!"
      expected_regex_string = ~S/^My full name is (?<full_name>"(.*)") I tell you!$/
      assert CucumberExpression.to_regex_string(expression) == expected_regex_string
    end
  end
end
