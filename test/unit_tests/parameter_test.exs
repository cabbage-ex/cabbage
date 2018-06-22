defmodule Cabbage.Feature.ParameterTest do
  use ExUnit.Case, async: true

  alias Cabbage.Feature.Parameter

  describe "converting cucumber expression term to parameter" do
    test "term in the form of {name:type} returns a parameter" do
      term = "{name:int}"
      result = Parameter.convert(term)
      assert result == %Cabbage.Feature.Parameter{capture_name: "name", type_regex: ~r/\d+/}
    end

    test "term not in the form of a parameter returns itself" do
      term = "coffee"
      result = Parameter.convert(term)
      assert result == "coffee"
    end
  end
end
