Code.require_file("test_helper.exs", __DIR__)

# Regression coverage for issue #94 (untagged scenarios).
#
# Cabbage does NOT auto-tag scenarios (e.g. with :integration). An untagged
# scenario must run by default, must not pick up unrelated tags, and the user
# can opt into ExUnit-style filtering via @moduletag. These tests lock that
# behavior in so the tag-merge path in `__before_compile__` cannot regress to
# auto-tagging or to dropping/duplicating tags for untagged scenarios.
defmodule Cabbage.FeatureUntaggedTest do
  use ExUnit.Case

  describe "untagged scenarios" do
    test "an untagged scenario runs by default and is not excluded by an unrelated tag filter" do
      defmodule UntaggedFeature do
        use Cabbage.Feature, file: "untagged.feature"

        defwhen ~r/^I provide When$/, _vars, _state do
        end

        defthen ~r/^I provide Then$/, _vars, _state do
        end
      end

      # Runs with no filter.
      {result, _output} = CabbageTestHelper.run([], [UntaggedFeature])
      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}

      # Excluding an arbitrary tag must NOT exclude the untagged scenario:
      # cabbage does not auto-apply tags.
      {result, _output} =
        CabbageTestHelper.run([exclude: [:integration]], [UntaggedFeature])

      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
    end

    test "an untagged scenario can be opted into exclusion via @moduletag" do
      defmodule UntaggedModuleTagFeature do
        use Cabbage.Feature, file: "untagged.feature"
        @moduletag :integration

        defwhen ~r/^I provide When$/, _vars, _state do
        end

        defthen ~r/^I provide Then$/, _vars, _state do
        end
      end

      {result, _output} =
        CabbageTestHelper.run([exclude: [:integration]], [UntaggedModuleTagFeature])

      assert result == %{failures: 0, skipped: 0, total: 1, excluded: 1}
    end
  end
end
