defmodule Cabbage.Feature.ParameterTest do
  use ExUnit.Case, async: true

  alias Cabbage.Feature.Parameter

  describe "extracting parameter from cucumber expression term" do
    test "term in the form of {name:type} returns a parameter" do
      term = "{name:int}"
      result = Parameter.extract(term)
      assert result == %Cabbage.Feature.Parameter{capture_name: "name", type_regex: ~r/\d+/}
    end

    test "term not in the form of a parameter returns nil" do
      term = "coffee"
      result = Parameter.extract(term)
      assert is_nil(result)
    end
  end
end
