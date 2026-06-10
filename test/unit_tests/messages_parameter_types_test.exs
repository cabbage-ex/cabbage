defmodule Cabbage.MessagesParameterTypesTest do
  @moduledoc """
  Unit tests for custom parameter types, regular-expression step definitions, and
  undefined parameter types in the message-emitting runner.

  These pin the cucumber-messages semantics the CCK `parameter-types`,
  `regular-expression`, and `unknown-parameter-type` areas require:

    * a custom parameter type registered on the `StepRegistry` is usable inside a
      Cucumber Expression, transforms its captures, and is surfaced for the
      `parameterType` message;
    * a regular-expression step definition matches directly and recovers each capture
      group's offset/value as `stepMatchArguments` (non-participating optional groups
      become empty groups);
    * a step whose Cucumber Expression references an *unregistered* `{type}` does not
      crash registration — it becomes an undefined step and the registry records the
      offending type name + expression for the `undefinedParameterType` message.
  """
  use ExUnit.Case, async: true

  alias Cabbage.Messages.{Matcher, StepRegistry}
  alias Cabbage.Messages.StepRegistry.StepDefinition

  describe "custom parameter types" do
    test "register, match, and transform a custom {flight} parameter type" do
      registry =
        StepRegistry.new()
        |> StepRegistry.define_parameter_type(
          name: "flight",
          regexp: ~r/([A-Z]{3})-([A-Z]{3})/,
          transform: fn [from, to] -> {from, to} end
        )
        |> StepRegistry.add("{flight} has been delayed", fn [flight] ->
          send(self(), {:flight, flight})
          :ok
        end)

      [match] = Matcher.matches(registry, "LHR-CDG has been delayed")

      # Transformed value feeds the step function.
      assert match.values == [{"LHR", "CDG"}]

      # stepMatchArguments: the {flight} group spans the whole token with two children
      # (the two capture groups of the custom regexp), tagged with the type name.
      assert match.arguments == [
               %{
                 "group" => %{
                   "start" => 0,
                   "value" => "LHR-CDG",
                   "children" => [
                     %{"start" => 0, "value" => "LHR"},
                     %{"start" => 4, "value" => "CDG"}
                   ]
                 },
                 "parameterTypeName" => "flight"
               }
             ]
    end

    test "custom parameter types are exposed for envelope emission, builtins are not" do
      registry =
        StepRegistry.new()
        |> StepRegistry.define_parameter_type(
          name: "flight",
          regexp: ~r/([A-Z]{3})-([A-Z]{3})/,
          transform: fn [from, to] -> {from, to} end,
          uri: "samples/parameter-types/parameter-types.ts",
          line: 11
        )

      assert [registered] = StepRegistry.parameter_types(registry)
      assert registered.name == "flight"
      assert registered.regexps == ["([A-Z]{3})-([A-Z]{3})"]
      assert registered.use_for_snippets == true
      assert registered.prefer_for_regexp_match == false
      assert registered.uri == "samples/parameter-types/parameter-types.ts"
      assert registered.line == 11
    end

    test "registering a duplicate parameter type name raises" do
      registry =
        StepRegistry.new()
        |> StepRegistry.define_parameter_type(name: "flight", regexp: ~r/[A-Z]{3}/)

      assert_raise Cabbage.CucumberExpression.Errors.CucumberExpressionError, fn ->
        StepRegistry.define_parameter_type(registry, name: "flight", regexp: ~r/[A-Z]{3}/)
      end
    end
  end

  describe "regular-expression step definitions" do
    test "a regex step def matches and recovers each group, with empty optional groups" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add(~r/^a (.*?)(?: and a (.*?))?(?: and a (.*?))?$/, fn _ -> :ok end)

      [%StepDefinition{pattern_kind: :regular_expression}] = StepRegistry.definitions(registry)

      [one] = Matcher.matches(registry, "a cucumber")

      assert one.arguments == [
               %{"group" => %{"start" => 2, "value" => "cucumber"}},
               %{"group" => %{}},
               %{"group" => %{}}
             ]

      [three] = Matcher.matches(registry, "a cucumber and a zucchini and a gourd")

      assert three.arguments == [
               %{"group" => %{"start" => 2, "value" => "cucumber"}},
               %{"group" => %{"start" => 17, "value" => "zucchini"}},
               %{"group" => %{"start" => 32, "value" => "gourd"}}
             ]
    end
  end

  describe "undefined parameter types" do
    test "a step referencing an unregistered {type} does not crash and becomes undefined" do
      registry =
        StepRegistry.new()
        |> StepRegistry.add("{airport} is closed because of a strike", fn _ -> :ok end)

      # The definition is recorded but flagged undefined, so it never matches.
      assert [%StepDefinition{pattern_kind: :undefined}] = StepRegistry.definitions(registry)
      assert Matcher.matches(registry, "CDG is closed because of a strike") == []

      # The registry remembers the offending type + expression for the message.
      assert [undefined] = StepRegistry.undefined_parameter_types(registry)
      assert undefined.name == "airport"
      assert undefined.expression == "{airport} is closed because of a strike"
    end
  end
end
