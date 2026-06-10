defmodule Cabbage.StepPatternTest do
  use ExUnit.Case, async: true

  alias Cabbage.StepPattern
  alias Cabbage.CucumberExpression
  alias Cabbage.CucumberExpression.ParameterTypeRegistry

  defp registry, do: ParameterTypeRegistry.new()
  defp classify(pattern), do: StepPattern.classify(pattern, registry())

  describe "classify/2" do
    test "a ~r// regex is passed through verbatim as {:regex, regex}" do
      regex = ~r/^there (is|are) (?<number>\d+) widgets?$/
      assert {:regex, ^regex} = classify(regex)
    end

    test "a binary with a {...} parameter classifies as a cucumber expression" do
      assert {:cucumber_expression, %CucumberExpression{} = expr} = classify("a {int} b")
      assert expr.source == "a {int} b"
    end

    test "a plain binary classifies as an anchored, escaped regex" do
      assert {:regex, %Regex{} = regex} = classify("plain $literal")
      # Matches ONLY the exact text, with the `$` escaped to a literal.
      assert "plain $literal" =~ regex
      refute "plain $literalX" =~ regex
      refute "Xplain $literal" =~ regex
      refute "plain Yliteral" =~ regex
    end

    test "a plain binary escapes every regex metacharacter to match literally" do
      {:regex, regex} = classify("a.b(c)+d*e?f")
      assert "a.b(c)+d*e?f" =~ regex
      refute "axbcd*e?f" =~ regex
    end

    test "a backslash-escaped brace routes to a cucumber expression (literal braces)" do
      # "\\{weird\\}" in Elixir source is the pattern `\{weird\}`; it contains a
      # `{...}` span so the binary-with-braces branch fires, but the braces are
      # escaped, so the compiled expression matches the literal text `{weird}`.
      assert {:cucumber_expression, %CucumberExpression{} = expr} = classify("\\{weird\\}")
      assert CucumberExpression.match(expr, "{weird}") == []
    end

    test "the {name:type} sugar raises a helpful Undefined parameter type error" do
      assert_raise Cabbage.CucumberExpression.Errors.CucumberExpressionError, fn ->
        classify("there are {count:int} rows")
      end
    end
  end

  describe "classify_expression/2 (Messages-layer policy)" do
    test "a braceless binary is still a cucumber expression (unlike classify/2)" do
      assert {:cucumber_expression, %CucumberExpression{} = expr} =
               StepPattern.classify_expression("an action", registry())

      assert expr.source == "an action"
      # classify/2 (Feature policy) would route the same braceless binary to a regex.
      assert {:regex, %Regex{}} = classify("an action")
    end

    test "a braces binary classifies as a cucumber expression" do
      assert {:cucumber_expression, %CucumberExpression{}} =
               StepPattern.classify_expression("I have {int} cukes in my belly", registry())
    end

    test "an anonymous {} parameter classifies as a cucumber expression" do
      assert {:cucumber_expression, %CucumberExpression{} = expr} =
               StepPattern.classify_expression("I have {} cukes", registry())

      assert StepPattern.match({:cucumber_expression, expr}, "I have x cukes") == {:ok, ["x"]}
    end

    test "a regex passes through verbatim" do
      regex = ~r/^a (.*?)(?: and a (.*?))?$/
      assert {:regex, ^regex} = StepPattern.classify_expression(regex, registry())
    end
  end

  describe "match/2 — cucumber expressions" do
    test "returns {:ok, positional_list} of transformed args" do
      assert StepPattern.match(classify("I have {int} cukes"), "I have 42 cukes") == {:ok, [42]}
    end

    test "a zero-parameter expression that matches returns {:ok, []} (NOT nil)" do
      # A parameter-free string classifies as a literal regex, so to exercise the
      # cucumber-expression branch's empty-match we compile one directly. The engine
      # returns [] (not nil) for a successful zero-parameter match; match/2 must
      # preserve that as {:ok, []}.
      expr = CucumberExpression.compile("a step passes", registry())
      assert StepPattern.match({:cucumber_expression, expr}, "a step passes") == {:ok, []}
    end

    test "returns nil for no match" do
      assert StepPattern.match(classify("I have {int} cukes"), "totally unrelated") == nil
    end

    test "transforms the built-in {float}, {word} and {string} types" do
      assert StepPattern.match(classify("pi is about {float}"), "pi is about 3.14") == {:ok, [3.14]}
      assert StepPattern.match(classify("a {word} thing"), "a small thing") == {:ok, ["small"]}
      assert StepPattern.match(classify("say {string} loud"), ~s(say "hi" loud)) == {:ok, ["hi"]}
    end

    test "binds multiple {...} parameters positionally, left to right" do
      assert StepPattern.match(classify("from {string} to {string}"), ~s(from "A" to "B")) ==
               {:ok, ["A", "B"]}
    end

    test "a custom parameter type transforms through its registry" do
      registry =
        ParameterTypeRegistry.new()
        |> ParameterTypeRegistry.define(
          Cabbage.CucumberExpression.ParameterType.new(
            name: "flight",
            regexps: [~r/([A-Z]{3})-([A-Z]{3})/],
            transform: fn [from, to] -> %{from: from, to: to} end
          )
        )

      classified = StepPattern.classify("{flight} has been delayed", registry)
      assert StepPattern.match(classified, "LHR-CDG has been delayed") == {:ok, [%{from: "LHR", to: "CDG"}]}
    end
  end

  describe "match/2 — regex" do
    test "returns {:ok, string-keyed named-captures map}" do
      assert StepPattern.match({:regex, ~r/(?<n>\d+)/}, "I have 42 cukes") == {:ok, %{"n" => "42"}}
    end

    test "multiple named captures all come back as strings" do
      classified = {:regex, ~r/^a (?<first>.*?) and a (?<second>.*?)$/}
      assert StepPattern.match(classified, "a x and a y") == {:ok, %{"first" => "x", "second" => "y"}}
    end

    test "a successful zero-capture regex match returns {:ok, %{}} (NOT nil)" do
      assert StepPattern.match({:regex, ~r/^a step$/}, "a step") == {:ok, %{}}
    end

    test "returns nil for no match" do
      assert StepPattern.match({:regex, ~r/(?<n>\d+)/}, "no digits here") == nil
    end

    test "an exact-literal classified regex matches only its literal text" do
      classified = classify("plain $literal")
      assert StepPattern.match(classified, "plain $literal") == {:ok, %{}}
      assert StepPattern.match(classified, "plain $literalX") == nil
    end
  end
end
