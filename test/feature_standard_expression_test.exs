Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureStandardExpressionTest do
  use ExUnit.Case

  # Proves cabbage routes standard Cucumber Expressions (anonymous `{int}`,
  # optional text `(s)`, alternation `cuke/banana`) through the real engine,
  # `Cabbage.CucumberExpression`, rather than the legacy `{name:type}` converter
  # or literal matching. See cabbage-ex/cabbage#47.
  test "anonymous parameters, optional text and alternation match real steps" do
    defmodule StandardExpressionFeature do
      use Cabbage.Feature, file: "standard_cucumber_expression.feature"

      defgiven "I start with {int} cuke(s)", _vars, _state do
        {:ok, %{given: true}}
      end

      defwhen "I add {int} cuke(s)", _vars, %{given: true} do
        {:ok, %{when: true}}
      end

      defthen "I end with {int} cuke(s)/banana(s)", _vars, %{given: true, when: true} do
        :ok
      end
    end

    {result, output} = CabbageTestHelper.run([], [StandardExpressionFeature])

    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
  end
end
