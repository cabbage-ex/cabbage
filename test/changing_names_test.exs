defmodule Cabbage.ChangingNamesTest do
  use Cabbage.Feature, file: "changing_names.feature"

  defgiven ~r/^I am a User$/, _vars, _state do
    nil
  end

  defand ~r/^I set my name to "(?<name>[^"]+)"$/, %{name: name}, _state do
    {:ok, %{username: name}}
  end

  defthen ~r/^my name is "(?<name>[^"]+)"$/, %{name: name}, %{username: username} do
    assert username == name
  end



end
