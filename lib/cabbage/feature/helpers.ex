defmodule Cabbage.Feature.Helpers do
  @moduledoc false
  def add_step(module, regex, vars, state, block, metadata) do
    steps = Module.get_attribute(module, :steps) || []
    Module.put_attribute(module, :steps, [{:{}, [], [regex, vars, state, block, metadata]} | steps])
    quote(do: nil)
  end

  def file(file) do
    String.replace_leading file, "#{File.cwd!}/", ""
  end

  def metadata(env, function) do
     %{file: file(env.file), line: env.line, module: env.module, function: function, arity: 4}
  end

  def stacktrace(module, metadata) do
    [{module, metadata[:function], metadata[:arity], [file: metadata[:file], line: metadata[:line]]}]
  end

  def agent_name(scenario_name) do
    :"cabbage_integration_test-#{scenario_name}"
  end

  @keys ~w(async case describe file integration line test type)a
  def remove_hidden_state(state) do
    Map.drop(state, @keys)
  end

end
