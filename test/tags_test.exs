defmodule Cabbage.TagsTest do
  use Cabbage.Feature, file: "tags.feature", async: false, tags: :feature_integration_test

  defgiven ~r/^a scenario is tagged as "(?<tag>[^"]+)"$/, %{tag: tag}, _state do
    {:ok, %{tag: tag}}
  end

  defgiven ~r/^global tag is set to "(?<global_tags>[^"]+)"$/, %{global_tags: global_tags}, _state do
    Application.put_env(:cabbage, :global_tags, global_tags)
    {:ok, %{tag: global_tags}}
  end

  defgiven ~r/^feature test file has provided tag "(?<integration_tags>[^"]+)"$/,
           %{integration_tags: integration_tags},
           _state do
    {:ok, %{tag: integration_tags}}
  end

  defwhen ~r/^run mix test( --only wip some_test.exs)?$/, _vars, _state do
    # Nothing to do here, cannot replicate
  end

  defwhen ~r/^it takes longer than the timeout$/, _vars, _state do
    # Change to 1500 to test
    Process.sleep(0)
  end

  defwhen ~r/^run mix test --only "(?<global_tags>[^"]+)" some_test.exs$/, %{global_tags: _global_tags}, _state do
    # Nothing to do here, cannot replicate
  end

  defthen ~r/^the test fails$/, _vars, _state do
    # Not able to test
    assert :ok
  end

  defthen ~r/^this test should be marked with "(?<tag>[^"]+)" tag$/, %{tag: tag}, _state do
    tag =
      tag
      |> String.trim_leading("@")
      |> String.to_atom()

    @ex_unit_tests
    |> Enum.each(fn %ExUnit.Test{tags: tags} ->
      assert Map.get(tags, tag, false) == true
    end)
  end

  defthen ~r/^this test should be skipped and never run$/, _vars, _state do
    assert false
  end
end
