Code.require_file("test_helper.exs", __DIR__)

# `defstep` is the keyword-neutral step macro; `defgiven`/`defwhen`/`defthen`
# (and `defand`/`defbut`) are aliases that register identically. Matching is by
# pattern only, so a `defstep` can match a `Given` pickle step and a `defgiven`
# can match a `Then` pickle step. This pins that keyword-agnosticism through the
# public macro surface.
defmodule Cabbage.FeatureDefstepTest do
  use ExUnit.Case

  test "defstep and the keyword macros match by pattern regardless of keyword" do
    defmodule DefstepFeature do
      use Cabbage.Feature, file: "simple.feature"

      setup do
        {:ok, %{count: 0}}
      end

      # `defstep` matches the `Given` pickle step.
      defstep ~r/^I provide Given$/, _vars, %{count: count} do
        {:ok, %{count: count + 1}}
      end

      # Keyword-macro /3 short form: pattern, state, do: block (vars defaults to ignore).
      defand ~r/^I provide And$/, %{count: count} do
        {:ok, %{count: count + 1}}
      end

      defstep ~r/^I provide When$/, %{count: count} do
        {:ok, %{count: count + 1}}
      end

      # `defgiven` matches the `Then` pickle step.
      defgiven ~r/^I provide Then$/, _vars, %{count: count} do
        assert count == 3
        :ok
      end
    end

    {result, output} = CabbageTestHelper.run([], [DefstepFeature])

    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
  end
end
