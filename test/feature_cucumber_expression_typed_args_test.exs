Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureCucumberExpressionTypedArgsTest do
  use ExUnit.Case

  # Proves a string Cucumber Expression pattern delivers its arguments to the
  # step block as a positional list of *transformed* values (`{int}` -> integer,
  # `{float}` -> float, `{string}` -> string) via `Cabbage.CucumberExpression`,
  # not as a string named-captures map. See cabbage-ex/cabbage#47.
  test "typed parameters arrive transformed and positional" do
    defmodule TypedArgsFeature do
      use Cabbage.Feature, file: "cucumber_expression_typed_args.feature"

      defgiven "I have {int} cucumbers", [count], _state do
        assert count === 42
        {:ok, %{count: count}}
      end

      defwhen "I add {float} kilograms", [weight], %{count: 42} do
        assert weight === 3.5
        {:ok, %{weight: weight}}
      end

      defthen "I eat the {string} one", [colour], %{count: 42, weight: 3.5} do
        assert colour === "green"
        :ok
      end
    end

    {result, output} = CabbageTestHelper.run([], [TypedArgsFeature])

    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
  end

  # A single feature module mixing regex (named-captures map) and Cucumber
  # Expression (positional list) step definitions: both pattern types must
  # coexist and bind their matched data in their respective shapes.
  test "regex and cucumber expression steps coexist in one module" do
    defmodule MixedPatternFeature do
      use Cabbage.Feature, file: "cucumber_expression_typed_args.feature"

      defgiven ~r/^I have (?<count>\d+) cucumbers$/, %{count: count}, _state do
        assert count === "42"
        {:ok, %{count: count}}
      end

      defwhen "I add {float} kilograms", [weight], %{count: "42"} do
        assert weight === 3.5
        {:ok, %{weight: weight}}
      end

      defthen "I eat the {string} one", [colour], %{count: "42", weight: 3.5} do
        assert colour === "green"
        :ok
      end
    end

    {result, output} = CabbageTestHelper.run([], [MixedPatternFeature])

    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
  end

  # A feature step with no matching definition — in a module whose registered
  # steps are Cucumber Expressions — must still raise the compile-time
  # `MissingStepError` with its regex snippet suggestion.
  test "missing step raises MissingStepError when definitions use cucumber expressions" do
    message = """
    Please add a matching step for:
    "When I add 3.5 kilograms"

      defwhen ~r/^I add 3.5 kilograms$/, _vars, state do
        # Your implementation here
      end
    """

    assert_raise Cabbage.Feature.MissingStepError, message, fn ->
      defmodule MissingStepExpressionFeature do
        use Cabbage.Feature, file: "cucumber_expression_typed_args.feature"

        defgiven "I have {int} cucumbers", [_count], _state do
          :ok
        end
      end
    end
  end

  # The removed `{name:type}` named-capture sugar must keep raising the spec
  # engine's clear "Undefined parameter type" error at compile time rather than
  # a cryptic failure. See UPGRADING.md.
  test "{name:type} sugar still raises a helpful compile-time error" do
    error =
      assert_raise Cabbage.CucumberExpression.Errors.CucumberExpressionError, fn ->
        defmodule NameTypeSugarFeature do
          use Cabbage.Feature, file: "cucumber_expression_typed_args.feature"

          defgiven "I have {count:int} cucumbers", [_count], _state do
            :ok
          end
        end
      end

    assert error.message =~ "Undefined parameter type 'count:int'"
  end
end
