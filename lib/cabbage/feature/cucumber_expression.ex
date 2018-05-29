defmodule Cabbage.Feature.CucumberExpression do

  # @parameters_types = [
  # ParameterType{name: "int", regex: "\d"}
  # ParameterType{name: "string", regex: ~r/d/}
   # ]

  def prepare(expression) do
    # Cucumber Expression {int} in step definition
    # Cucumber Expression \d in step definition
    # tokens = String.split(expression)
    # Enum.map(tokens, fn(token) ->
    #   # match
    # end)
    ~r/^#{expression}$/
  end
end
