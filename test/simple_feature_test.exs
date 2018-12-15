defmodule SimpleFeatureTest do
  use Cabbage.FeatureCase, feature: "simple.feature"

  # test "some" do
  #   IO.inspect(steps())
  # end

  defgiven ~r/^I provide Given$/, _vars, _state do
    {:ok, %{tes: "some"}}
  end

  defgiven ~r/^I provide (?<string_1>[^\"]+)$/, %{string_1: string_1}, _state do
  end

  defwhen ~r/^I provide When$/, _vars, %{tes: value} do
    # IO.inspect(value, label: :something)
  end

  #
  defthen ~r/^I provide Then$/, _vars, _state do
    # Your implementation here
  end
end
