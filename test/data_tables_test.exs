defmodule Cabbage.DataTableTest do
  use Cabbage.Feature, file: "data_tables.feature"

  defgiven ~r/^the following data table$/,
           %{table: [%{id: "1", name: "Luke"}, %{id: "2", name: "Darth"}]},
           _state do
    :ok
  end

  defwhen ~r/^I run a the test file$/, _vars, _state do
    :ok
  end

  defthen ~r/^in the step definition I should get a var with the value$/,
          %{doc_string: string},
          _state do
    assert ~s([%{id: "1", name: "Luke"}, %{id: "2", name: "Darth"}]) == String.trim(string)
  end
end
