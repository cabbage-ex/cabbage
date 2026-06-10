Code.require_file("test_helper.exs", __DIR__)

# Regression coverage for issue #64 (allow matching exact strings).
#
# A plain string step pattern that contains no cucumber-expression parameter
# (`{int}`, `{}`) should match the step text *literally* - regex metacharacters
# like $, (, ), +, . must be treated as literal characters rather than regex
# syntax. Parameterized strings still flow through the cucumber-expression
# engine (covered by feature_standard_expression_test.exs).
defmodule Cabbage.FeatureExactStringTest do
  use ExUnit.Case

  test "plain string steps match literally, including regex metacharacters" do
    defmodule ExactStringFeature do
      use Cabbage.Feature, file: "exact_string.feature"

      defgiven "It costs $5 (USD)", _vars, _state do
        {:ok, %{given: true}}
      end

      defwhen "I add 1 + 1 = 2", _vars, %{given: true} do
        {:ok, %{when: true}}
      end

      defthen "the result is a.b.c", _vars, %{given: true, when: true} do
        :ok
      end
    end

    {result, output} = CabbageTestHelper.run([], [ExactStringFeature])

    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
  end
end
