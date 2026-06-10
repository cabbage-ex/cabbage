defmodule Cabbage.TagExpressionTest do
  use ExUnit.Case, async: true

  alias Cabbage.TagExpression

  doctest Cabbage.TagExpression

  describe "parse/1 and to_string/1" do
    test "empty expression parses to the always-true node rendering as empty string" do
      assert {:ok, expr} = TagExpression.parse("")
      assert to_string(expr) == ""
    end

    test "a bare tag is the simplest expression" do
      assert {:ok, expr} = TagExpression.parse("@a")
      assert to_string(expr) == "@a"
    end

    test "binary operators render fully parenthesised" do
      assert {:ok, expr} = TagExpression.parse("a and b")
      assert to_string(expr) == "( a and b )"
    end

    test "not wraps its operand" do
      assert {:ok, expr} = TagExpression.parse("not a")
      assert to_string(expr) == "not ( a )"
    end

    test "and is left-associative" do
      assert {:ok, expr} = TagExpression.parse("a and b and c")
      assert to_string(expr) == "( ( a and b ) and c )"
    end

    test "precedence: not > and > or" do
      assert {:ok, expr} = TagExpression.parse("a or b and not c")
      assert to_string(expr) == "( a or ( b and not ( c ) ) )"
    end

    test "escaped parens are part of the tag name" do
      assert {:ok, expr} = TagExpression.parse("x\\(1\\) or y")
      assert to_string(expr) == "( x\\(1\\) or y )"
    end

    test "escaped space is part of the tag name" do
      assert {:ok, expr} = TagExpression.parse("x\\  or y")
      assert to_string(expr) == "( x\\  or y )"
    end

    test "round-trips: parsing the formatted form is idempotent" do
      for input <- ["", "a", "a and b", "not (a or b)", "x\\(1\\) or y"] do
        {:ok, parsed} = TagExpression.parse(input)
        formatted = to_string(parsed)
        {:ok, reparsed} = TagExpression.parse(formatted)
        assert to_string(reparsed) == formatted
      end
    end
  end

  describe "evaluate/2" do
    test "empty expression is always true" do
      assert TagExpression.evaluate("", []) == true
      assert TagExpression.evaluate("", ["@x"]) == true
    end

    test "literal membership" do
      assert TagExpression.evaluate("@a", ["@a"]) == true
      assert TagExpression.evaluate("@a", ["@b"]) == false
    end

    test "and / or / not" do
      assert TagExpression.evaluate("@a and @b", ["@a", "@b"]) == true
      assert TagExpression.evaluate("@a and @b", ["@a"]) == false
      assert TagExpression.evaluate("@a or @b", ["@b"]) == true
      assert TagExpression.evaluate("not @a", ["@b"]) == true
      assert TagExpression.evaluate("@a and not @b", ["@a"]) == true
    end

    test "accepts a pre-parsed node" do
      {:ok, expr} = TagExpression.parse("@a or @b")
      assert TagExpression.evaluate(expr, ["@b"]) == true
    end
  end

  describe "errors" do
    test "exact reference wording for a trailing operator" do
      assert TagExpression.parse("a and") ==
               {:error, ~s(Tag expression "a and" could not be parsed because of syntax error: Expected operand.)}
    end

    test "two operands without an operator" do
      assert {:error, msg} = TagExpression.parse("a b")
      assert msg =~ "Expected operator."
    end

    test "unmatched parens" do
      assert {:error, msg} = TagExpression.parse("( a and b ) )")
      assert msg =~ "Unmatched )."
      assert {:error, msg} = TagExpression.parse("( ( a and b )")
      assert msg =~ "Unmatched (."
    end

    test "illegal escape" do
      assert {:error, msg} = TagExpression.parse("x or \\y or z")

      assert msg ==
               ~s(Tag expression "x or \\y or z" could not be parsed because of syntax error: Illegal escape before "y".)
    end
  end

  describe "parse!/1" do
    test "raises on invalid input" do
      assert_raise Cabbage.TagExpression.SyntaxError, fn -> TagExpression.parse!("a and") end
    end

    test "returns the node on valid input" do
      assert %Cabbage.TagExpression.And{} = TagExpression.parse!("a and b")
    end
  end
end
