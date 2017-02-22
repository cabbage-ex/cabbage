defmodule Cabbage.Feature.Helpers do
  @moduledoc false
  def add_step(module, regex, vars, state, block, metadata) do
    steps = Module.get_attribute(module, :steps) || []
    Module.put_attribute(module, :steps, [{:{}, [], [regex, vars, state, block, metadata]} | steps])
    quote(do: nil)
  end

  def add_tag(module, "@" <> tag_name, block), do: add_tag(module, tag_name, block)
  def add_tag(module, tag_name, block) do
    tags = Module.get_attribute(module, :tags) || []
    Module.put_attribute(module, :tags, [{tag_name, block} | tags])
    quote(do: nil)
  end

  def evaluate_tag_block(block) do
    {new_state, _} = Code.eval_quoted(block)
    case new_state do
      {:ok, state} -> state
      _ -> %{}
    end
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

  def agent_name(scenario_name, module_name) do
    :"cabbage_integration_test-#{scenario_name}-#{module_name}"
  end

  @keys ~w(async case describe file integration line test type scenario registered)a
  def remove_hidden_state(state) do
    Map.drop(state, @keys)
  end

  def fetch_state(scenario_name, module_name) do
    scenario_name
    |> agent_name(module_name)
    |> Agent.get(&(&1))
  end

  def update_state(scenario_name, module_name, fun) do
    scenario_name
    |> agent_name(module_name)
    |> Agent.update(fun)
  end

end
