Code.require_file("test_helper.exs", __DIR__)

# The full step-return state contract:
#
#   :ok | nil          -> context unchanged
#   a map              -> REPLACES the context with that map
#   {:ok, map}         -> Map.merge(context, map)   (delta-merge; back-compat)
#   {:error, reason}   -> raises a clear error naming the step + reason
#   a struct           -> raises (context must be a plain map; bare or {:ok, _}-wrapped)
#   anything else      -> raises a clear error naming the step + offending value
defmodule Cabbage.FeatureStateContractTest do
  use ExUnit.Case

  describe "keep-state returns" do
    test ":ok leaves the context unchanged" do
      defmodule ContractOkFeature do
        use Cabbage.Feature, file: "simple.feature"

        setup do
          {:ok, %{acc: []}}
        end

        defgiven ~r/^I provide Given$/, _vars, %{acc: acc} do
          {:ok, %{acc: [:given | acc]}}
        end

        defgiven ~r/^I provide And$/, _vars, _state do
          :ok
        end

        defwhen ~r/^I provide When$/, _vars, _state do
          nil
        end

        defthen ~r/^I provide Then$/, _vars, %{acc: acc} do
          assert acc == [:given]
          :ok
        end
      end

      {result, output} = CabbageTestHelper.run([], [ContractOkFeature])
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
    end
  end

  describe "merge vs replace" do
    test "{:ok, map} merges the delta into the context" do
      defmodule ContractMergeFeature do
        use Cabbage.Feature, file: "simple.feature"

        setup do
          {:ok, %{keep: :me}}
        end

        defgiven ~r/^I provide Given$/, _vars, _state do
          {:ok, %{added: 1}}
        end

        defgiven(~r/^I provide And$/, _vars, _state, do: :ok)
        defwhen(~r/^I provide When$/, _vars, _state, do: :ok)

        defthen ~r/^I provide Then$/, _vars, ctx do
          assert ctx.keep == :me
          assert ctx.added == 1
          :ok
        end
      end

      {result, output} = CabbageTestHelper.run([], [ContractMergeFeature])
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
    end

    test "a bare map REPLACES the context" do
      defmodule ContractReplaceFeature do
        use Cabbage.Feature, file: "simple.feature"

        setup do
          {:ok, %{keep: :me}}
        end

        defgiven ~r/^I provide Given$/, _vars, _state do
          %{only: :this}
        end

        defgiven(~r/^I provide And$/, _vars, _state, do: :ok)
        defwhen(~r/^I provide When$/, _vars, _state, do: :ok)

        defthen ~r/^I provide Then$/, _vars, ctx do
          # The replace dropped the seeded `:keep` key entirely.
          refute Map.has_key?(ctx, :keep)
          assert ctx.only == :this
          :ok
        end
      end

      {result, output} = CabbageTestHelper.run([], [ContractReplaceFeature])
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}, output
    end
  end

  describe "fail-loud returns" do
    test "{:error, reason} raises a clear error naming the step and reason" do
      defmodule ContractErrorFeature do
        use Cabbage.Feature, file: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          {:error, :boom}
        end
      end

      {result, output} = CabbageTestHelper.run([], [ContractErrorFeature])
      assert result == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      assert output =~ "I provide Then"
      assert output =~ ":boom"
    end

    test "a non-conforming return raises naming the step and the offending value" do
      defmodule ContractBadReturnFeature do
        use Cabbage.Feature, file: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          :unexpected_atom
        end
      end

      {result, output} = CabbageTestHelper.run([], [ContractBadReturnFeature])
      assert result == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      assert output =~ "I provide Then"
      assert output =~ ":unexpected_atom"
      assert output =~ ":ok | nil | a map | {:ok, map}"
    end

    test "a struct return raises (context must be a plain map)" do
      defmodule ContractStructFeature do
        use Cabbage.Feature, file: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          %URI{}
        end
      end

      {result, output} = CabbageTestHelper.run([], [ContractStructFeature])
      assert result == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      assert output =~ "I provide Then"
      assert output =~ "URI"
      assert output =~ "plain map"
    end

    test "{:ok, struct} raises instead of merging struct fields into the context" do
      defmodule ContractOkStructFeature do
        use Cabbage.Feature, file: "simplest.feature"

        defthen ~r/^I provide Then$/, _vars, _state do
          {:ok, %URI{}}
        end
      end

      {result, output} = CabbageTestHelper.run([], [ContractOkStructFeature])
      assert result == %{failures: 1, skipped: 0, total: 1, excluded: 0}
      assert output =~ "I provide Then"
      assert output =~ "URI"
      assert output =~ "plain map"
    end
  end
end
