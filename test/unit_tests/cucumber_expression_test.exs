defmodule Cabbage.Feature.CucumberExpressionTest do
  use ExUnit.Case
  alias Cabbage.Feature.CucumberExpression

  describe "converting cucumber expressions to regex" do
    test "convert simple string" do
      assert CucumberExpression.to_regex("simple string").source == ~r/^simple string$/.source
    end

    test "convert string containing type integer" do
      assert CucumberExpression.to_regex("{quantity:int} string").source == ~r/^(?<quantity>\d+) string$/.source
    end

    test "convert string containing 2 integer types" do
      string = "{tea_count:int} tea and {coffee_count:int} coffee"
      expected_regex = ~r/^(?<tea_count>\d+) tea and (?<coffee_count>\d+) coffee$/.source
      assert CucumberExpression.to_regex(string).source == expected_regex
    end

    test "convert string containing float" do
      string = "It cost $ {cost:float}"
      expected_regex = ~r/^It cost $ (?<cost>\d+\.\d+)$/.source
      assert CucumberExpression.to_regex(string).source == expected_regex
    end

    test "convert string containing float and integer" do
      string = "It cost $ {price:int} or $ {cost:float} to be precise"
      expected_regex = ~r/^It cost $ (?<price>\d+) or $ (?<cost>\d+\.\d+) to be precise$/.source
      assert CucumberExpression.to_regex(string).source == expected_regex
    end

    test "convert string containing word" do
      string = "My name is {name:word} I tell you!"
      expected_regex = ~r/^My name is (?<name>\w*\S) I tell you!$/.source
      assert CucumberExpression.to_regex(string).source == expected_regex
    end

    test "convert string containing string" do
      string = "My full name is {full_name:string} I tell you!"
      expected_regex = ~r/^My full name is (?<full_name>"(.*)") I tell you!$/.source
      assert CucumberExpression.to_regex(string).source == expected_regex
    end
  end
end
