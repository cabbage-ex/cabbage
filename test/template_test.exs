defmodule Cabbage.TemplateTest do
  use Cabbage.Feature, template: Cabbage.ExUnit.CaseTemplate, file: "coffee.feature"
  import_feature Cabbage.GlobalFeatures

  defwhen ~r/^I press the coffee button$/, _, %{case_template: template, deposited: deposited} do
    assert Cabbage.ExUnit.CaseTemplate = template
    {:ok, %{deposited: deposited - 1}}
  end

  defthen ~r/^I should be served a coffee$/, _, %{case_template: template, coffees: coffees} do
    assert Cabbage.ExUnit.CaseTemplate = template
    assert coffees - 1 >= 0
    {:ok, %{coffees: coffees - 1}}
  end

  defthen ~r/^I should be frustrated$/, _, %{case_template: template, coffees: coffees} do
    assert Cabbage.ExUnit.CaseTemplate = template
    assert coffees - 1 < 0
    {:ok, %{coffees: coffees - 1}}
  end
end
