defmodule Cabbage.CucumberExpressionsTest do
  use Cabbage.Feature, file: "cucumber_expressions.feature"
  alias Gherkin.Elements.Scenario
  doctest Cabbage.Feature

  test "has a @feature" do
    assert "Support cucumber expressions" = @feature.name
    assert %Scenario{steps: [_ | _]} = @feature.scenarios |> hd()
  end

  setup do
    {:ok, %{}}
  end

  defgiven "Step definition using string as first parameter", _, %{} do
    {:ok, %{}}
  end

  defwhen ~r/^I run the test file$/, _, _ do
    {:ok, %{}}
  end

  defthen ~r/^I should see it passing$/, _, _ do
    {:ok, %{}}
  end
end
