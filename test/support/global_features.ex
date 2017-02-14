defmodule Cabbage.GlobalFeatures do
  use Cabbage.Feature

  tag @coffee do
    IO.puts "Printing stuff"
    {:ok, %{tag: :data}}
  end

  defgiven ~r/^there are (?<number>\d+) coffees left in the machine$/, %{number: number}, %{starting: :state, tag: :data} do
    {:ok, %{coffees: String.to_integer(number)}}
  end

  defand ~r/^I have deposited \$(?<money>\d+)$/, %{money: money}, %{coffees: _coffees, tag: :data} do
    {:ok, %{deposited: String.to_integer(money)}}
  end
end
