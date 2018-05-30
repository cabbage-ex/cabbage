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

  defgiven "Step definition using {count:int} int", captures, %{} do
    {:ok, captures}
  end

  defand "{quantity:float} float", captures, _ do
    {:ok, captures}
  end

  defand "{word_count:word} word", captures, _ do
    {:ok, captures}
  end

  defand "{matched_str:string} string", captures, _ do
    {:ok, captures}
  end

  defwhen ~r/^I check type of named captures$/, _, _ do
    {:ok, %{}}
  end

  defthen ~r/^Named captures are of expected type$/, _, %{count: count, quantity: quantity, word_count: word_count, matched_str: matched_str} do
    assert count == "1"
    assert quantity == "1.0"
    assert word_count == "one"
    assert matched_str == "\"one simple\""
    {:ok, %{}}
  end
end
