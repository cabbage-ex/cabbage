defmodule Cabbage.GlobalFeatures do
  use Cabbage.Feature

  tag @coffee do
    {:ok, %{tagged: :data}}
  end

  tag @no-coffee do
    nil # Works fine
  end

  tag @last_chance do
    :ok # Also works
  end

  defgiven ~r/^there are (?<number>\d+) coffees left in the machine$/, %{number: number}, %{starting: :state, tagged: :data} do
    {:ok, %{coffees: String.to_integer(number)}}
  end

  defand ~r/^I have deposited \$(?<money>\d+)$/, %{money: money}, %{coffees: _coffees, tagged: :data} do
    {:ok, %{deposited: String.to_integer(money)}}
  end
end
