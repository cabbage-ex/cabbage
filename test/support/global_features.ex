defmodule Cabbage.GlobalFeatures do
  use Cabbage.Feature

  defgiven ~r/^there are (?<number>\d+) coffees left in the machine$/, %{number: number}, %{starting: :state} do
    {:ok, %{coffees: String.to_integer(number)}}
  end

  defand ~r/^I have deposited \$(?<money>\d+)$/, %{money: money}, %{coffees: _coffees} do
    {:ok, %{deposited: String.to_integer(money)}}
  end
end
