Code.require_file("test_helper.exs", __DIR__)

# A step's gherkin table and doc string are reachable from the context map
# under the reserved keys `:__table__` / `:__doc_string__`. This is the uniform
# path that also works for cucumber-expression (string-pattern) steps, whose
# matched data is a positional list with no room for named `:table`/`:doc_string`.
# The reserved keys are injected per step (each step sees its OWN gherkin data)
# and must NOT be threaded forward: a `:ok`/`nil`/`{:ok, _}` return strips them so
# they cannot accumulate or appear in a later step's threaded-state destructure.
defmodule Cabbage.FeatureContextTableTest do
  use ExUnit.Case

  @complex_doc_string """
  Here is provided some complex part that is way to complex
  """

  @expected_table [%{Age: "30", Name: "John"}, %{Age: "29", Name: "Ann"}]

  test "cucumber-expression steps read tables and doc strings via context reserved keys" do
    defmodule ContextTableFeature do
      use Cabbage.Feature, file: "dynamic.feature", async: true

      defgiven ~r/^I provide Given with \'(?<string_1>[^\']+)\' part$/, _vars, ctx do
        # A regex step with no table/doc-string: absent gherkin data is the empty
        # list / empty string (loader defaults), exposed on this step's context.
        assert ctx.__table__ == []
        assert ctx.__doc_string__ == ""
        {:ok, %{from_given: ctx.__doc_string__}}
      end

      defwhen ~r/^I provide When with \"(?<string_1>[^\"]+)\" part and with one more \"(?<string_2>[^\"]+)\" part$/,
              _vars,
              ctx do
        # The previous step's reserved-key VALUES were not threaded forward: the
        # `from_given` delta carries the empty doc string, not a stale leak, and
        # this step sees its own (also empty) gherkin data.
        assert ctx.from_given == ""
        assert ctx.__table__ == []
        assert ctx.__doc_string__ == ""
        :ok
      end

      # Cucumber Expression (string pattern => positional `vars`) reading the doc
      # string from the context rather than from named captures.
      defthen "I provide Then with number {int} part and with docs part", [number], ctx do
        assert number == 6
        assert ctx.__doc_string__ == unquote(@complex_doc_string)
        # This step carries a doc string but no table.
        assert ctx.__table__ == []
        {:ok, %{saw_doc_string: ctx.__doc_string__}}
      end

      # Cucumber Expression step reading the data table from the context.
      defthen "I provide And with {string} part and with one more {string} part and with table part",
              [_s1, _s2],
              ctx do
        assert ctx.__table__ == unquote(Macro.escape(@expected_table))
        # The previous step's doc string was threaded as `:saw_doc_string`, but the
        # reserved `:__doc_string__` value did NOT leak: this step's own doc string
        # is empty, proving reserved keys are re-injected per step, never carried.
        assert ctx.saw_doc_string == unquote(@complex_doc_string)
        assert ctx.__doc_string__ == ""
        :ok
      end
    end

    {result, _output} = CabbageTestHelper.run()
    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
  end
end
