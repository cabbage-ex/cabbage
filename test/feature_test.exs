defmodule Cabbage.FeatureTest do
  use Cabbage.Feature, file: "coffee.feature"
  alias Gherkin.Elements.Scenario
  doctest Cabbage.Feature

  import_feature Cabbage.GlobalFeatures
  import_steps Cabbage.TaglessFeatures

  test "has an @feature" do
    assert "Serve coffee" = @feature.name
    assert %Scenario{steps: [_ | _]} = @feature.scenarios |> hd()
  end

  setup do
    {:ok, %{starting: :state}}
  end

  defwhen ~r/^I press the coffee button$/, _, %{deposited: deposited} do
    {:ok, %{deposited: deposited - 1}}
  end

  defthen ~r/^I should be served a coffee$/, _, %{coffees: coffees} do
    assert coffees - 1 >= 0
    {:ok, %{coffees: coffees - 1}}
  end

  defthen ~r/^I should be frustrated$/, _, %{coffees: coffees} do
    assert coffees - 1 < 0
    {:ok, %{coffees: coffees - 1}}
  end

end
