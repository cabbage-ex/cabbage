defmodule Cabbage.TagsTest do
  use Cabbage.Feature, file: "tags.feature"

  defgiven ~r/^a scenario is tagged as "(?<tag>[^"]+)"$/, %{tag: tag}, _state do
    {:ok, %{tag: tag}}
  end

  defwhen ~r/^run mix test --only wip some_test.exs$/, _vars, _state do
    # Nothing to do here, cannot replicate
  end

  defthen ~r/^this test should be marked with that tag$/, _vars, %{tag: _tag} do
    assert %ExUnit.Test{tags: %{wip: true}} = @ex_unit_tests |> hd()
  end
end
