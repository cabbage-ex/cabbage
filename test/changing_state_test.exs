defmodule Cabbage.ChangingStateTest do
  use Cabbage.Feature, async: true, file: "changing_state.feature"

  setup _context do
    {:ok, params: %{start: :state}}
  end

  defgiven ~r/^a start state$/, _vars, state do
    {:ok, state}
  end

  defthen ~r/^the state is not changed$/, _vars, state do
    assert state.params == %{start: :state}
    {:ok, state}
  end

  defwhen ~r/^I change the state$/, _vars, state do
    {:ok, %{params: %{new: :state}}}
  end

  defthen ~r/^the state is changed$/, _vars, state do
    assert state.params == %{new: :state}
    {:ok, state}
  end
end
