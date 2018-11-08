defmodule Cabbage.OutlineTest do
  use Cabbage.Feature, file: "coffee_outline.feature"

  import_feature(Cabbage.GlobalFeatures)

  setup do
    {:ok, %{starting: :state}}
  end

  defwhen ~r/^I press the coffee button$/, _, %{deposited: deposited} do
    {:ok, %{deposited: deposited - 1}}
  end

  defthen ~r/^I should be served (?<served>\d+) coffees$/, %{served: served}, %{coffees: coffees} do
    served = String.to_integer(served)
    assert coffees - served >= 0
    {:ok, %{coffees: coffees - served}}
  end
end
