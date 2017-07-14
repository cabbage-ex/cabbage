defmodule Cabbage.TagsTest do
  use Cabbage.Feature, file: "tags.feature"

  defgiven ~r/^a scenario is tagged as "(?<tag>[^"]+)"$/, %{tag: tag}, _state do
    {:ok, %{tag: tag}}
  end

  defwhen ~r/^run mix test --only wip some_test.exs$/, _vars, _state do
    # Nothing to do here
  end

  defthen ~r/^this test should be marked with that tag$/, _vars, %{tag: _tag} do
    # unable to do: Module.get_attribute(__MODULE__, String.to_atom(tag))
  end
end
