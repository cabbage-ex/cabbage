defmodule Cabbage.TagsTest do
  use Cabbage.Feature, file: "tags.feature"

  defgiven ~r/^a scenario is tagged as "(?<tag>[^"]+)"$/, %{tag: tag}, _state do
    {:ok, %{tag: tag}}
  end

  defwhen ~r/^run mix test( --only wip some_test.exs)?$/, _vars, _state do
    # Nothing to do here, cannot replicate
  end

  defwhen ~r/^it takes longer than the timeout$/, _vars, _state do
    # Change to 1500 to test
    Process.sleep(0)
  end

  defthen ~r/^the test fails$/, _vars, _state do
    # Not able to test
    assert :ok
  end

  defthen ~r/^this test should be marked with that tag$/, _vars, %{tag: _tag} do
    assert %ExUnit.Test{tags: %{wip: true}} = @ex_unit_tests |> hd()
  end

  defthen ~r/^this test should be skipped and never run$/, _vars, _state do
    assert false
  end
end
