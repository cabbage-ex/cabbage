defmodule Cabbage.CucumberExpression.EngineTest do
  use ExUnit.Case, async: true

  alias Cabbage.CucumberExpression
  alias Cabbage.CucumberExpression.{Parser, ParameterTypeRegistry, Tokenizer}
  alias Cabbage.CucumberExpression.Errors.CucumberExpressionError

  defp registry, do: ParameterTypeRegistry.new()
  defp compile(expr), do: CucumberExpression.compile(expr, registry())
  defp match(expr, text), do: CucumberExpression.match(compile(expr), text)
  defp to_regex(expr), do: CucumberExpression.to_regex(expr, registry())

  describe "tokenizer" do
    test "bookends with START_OF_LINE / END_OF_LINE" do
      tokens = Tokenizer.tokenize("a")
      assert List.first(tokens)["type"] == "START_OF_LINE"
      assert List.last(tokens)["type"] == "END_OF_LINE"
    end

    test "splits text, whitespace and reserved tokens with codepoint offsets" do
      types = "a {b}" |> Tokenizer.tokenize() |> Enum.map(& &1["type"])

      assert types == [
               "START_OF_LINE",
               "TEXT",
               "WHITE_SPACE",
               "BEGIN_PARAMETER",
               "TEXT",
               "END_PARAMETER",
               "END_OF_LINE"
             ]
    end

    test "an escaped reserved char becomes literal TEXT spanning the source" do
      [_sol, text, _eol] = Tokenizer.tokenize("\\(blind\\)")
      assert text == %{"type" => "TEXT", "start" => 0, "end" => 9, "text" => "(blind)"}
    end

    test "raises on an unescapable character" do
      assert_raise CucumberExpressionError, ~r/can be escaped/, fn -> Tokenizer.tokenize("\\[") end
    end

    test "raises when the line ends with a backslash" do
      assert_raise CucumberExpressionError, ~r/end of line can not be escaped/, fn ->
        Tokenizer.tokenize("\\")
      end
    end
  end

  describe "parser" do
    test "empty expression -> empty EXPRESSION_NODE" do
      assert Parser.parse("") == %{
               "type" => "EXPRESSION_NODE",
               "start" => 0,
               "end" => 0,
               "nodes" => []
             }
    end

    test "a parameter parses to PARAMETER_NODE wrapping a TEXT_NODE" do
      ast = Parser.parse("{int}")
      [param] = ast["nodes"]
      assert param["type"] == "PARAMETER_NODE"
      assert [%{"type" => "TEXT_NODE", "token" => "int"}] = param["nodes"]
    end

    test "alternation parses to ALTERNATION_NODE of ALTERNATIVE_NODEs" do
      ast = Parser.parse("a/b")
      [alt] = ast["nodes"]
      assert alt["type"] == "ALTERNATION_NODE"
      assert Enum.map(alt["nodes"], & &1["type"]) == ["ALTERNATIVE_NODE", "ALTERNATIVE_NODE"]
    end

    test "raises on an unterminated parameter" do
      assert_raise CucumberExpressionError, ~r/does not have a matching '}'/, fn ->
        Parser.parse("{string")
      end
    end

    test "raises on a reserved character in a parameter name" do
      assert_raise CucumberExpressionError, ~r/Parameter names may not contain/, fn ->
        Parser.parse("{(string)}")
      end
    end
  end

  describe "to_regex (transformation)" do
    test "plain text is anchored and regex-escaped" do
      assert to_regex("a.b") == "^a\\.b$"
    end

    test "{int} expands to its two alternatives" do
      assert to_regex("{int}") == "^((?:-?\\d+)|(?:\\d+))$"
    end

    test "optional becomes a non-capturing optional group" do
      assert to_regex("(a)") == "^(?:a)?$"
    end

    test "alternation becomes a non-capturing alternation" do
      assert to_regex("a/b c/d/e") == "^(?:a|b) (?:c|d|e)$"
    end

    test "anonymous parameter becomes a capture of .*" do
      assert to_regex("{}") == "^(.*)$"
    end
  end

  describe "match" do
    test "{int} transforms to an integer" do
      assert match("I have {int} cukes", "I have 42 cukes") == [42]
    end

    test "negative ints and floats" do
      assert match("{int}", "-7") == [-7]
      assert match("{float}", "-3.5") == [-3.5]
      assert match("{float}", ".22") == [0.22]
    end

    test "{string} strips quotes and unescapes" do
      assert match("say {string}", ~s/say "he said \\"hi\\""/) == [~s/he said "hi"/]
    end

    test "anonymous parameter returns the raw matched text" do
      assert match("{}", "0.22") == ["0.22"]
    end

    test "biginteger keeps full precision as an Elixir integer" do
      big = "31415926535897932384626433832795028841971693993751058209749445923078164062862089986280348253421170679"
      assert match("{biginteger}", big) == [String.to_integer(big)]
    end

    test "optional text matches with or without the optional" do
      assert match("I have {int} cuke(s)", "I have 1 cuke") == [1]
      assert match("I have {int} cuke(s)", "I have 2 cukes") == [2]
    end

    test "alternation matches any alternative" do
      assert match("{int} cuke(s)/banana(s)", "1 cuke") == [1]
      assert match("{int} cuke(s)/banana(s)", "3 bananas") == [3]
    end

    test "returns nil when the text does not match" do
      assert match("I have {int} cukes", "I have lots of cukes") == nil
    end
  end

  describe "errors raised during regex generation" do
    test "undefined parameter type" do
      assert_raise CucumberExpressionError, ~r/Undefined parameter type 'unknown'/, fn ->
        compile("{unknown}")
      end
    end

    test "empty optional" do
      assert_raise CucumberExpressionError, ~r/An optional must contain some text/, fn ->
        compile("three () mice")
      end
    end

    test "nested optional" do
      assert_raise CucumberExpressionError, ~r/may not contain an other optional/, fn ->
        compile("(a(b))")
      end
    end

    test "empty alternative" do
      assert_raise CucumberExpressionError, ~r/Alternative may not be empty/, fn ->
        compile("a//b")
      end
    end
  end

  describe "parameter type registry" do
    test "looks up built-ins and rejects duplicate registration" do
      reg = registry()
      assert ParameterTypeRegistry.lookup_by_type_name(reg, "int")

      dup = Cabbage.CucumberExpression.ParameterType.new(name: "int", regexps: ["x"])

      assert_raise CucumberExpressionError, ~r/already a parameter type/, fn ->
        ParameterTypeRegistry.define(reg, dup)
      end
    end
  end
end
