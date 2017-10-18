defmodule Cabbage.Feature.Helpers do
  @moduledoc false
  require Logger

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

  @keys ~w(async case describe file integration line test type scenario case_templae registered)a
  def remove_hidden_state(state) do
    Map.drop(state, @keys)
  end

  def start_state(scenario_name, module_name, state) do
    name = scenario_name |> agent_name(module_name)
    agent = Process.whereis(name)
    if agent do
      update_state(scenario_name, module_name, fn s -> Map.merge(s, state) |> remove_hidden_state() end)
    else
      Agent.start(fn -> state end, name: name)
    end
  end

  def fetch_state(scenario_name, module_name) do
    name = scenario_name |> agent_name(module_name)
    (Process.whereis(name) && Agent.get(name, &(&1)) || %{}) |> remove_hidden_state()
  end

  def update_state(scenario_name, module_name, fun) do
    scenario_name
    |> agent_name(module_name)
    |> Agent.update(fun)
  end

  def run_tag(tags, tag, module, scenario_name) do
    string_tag = to_string(tag)
    case Enum.find(tags, &(match?({^string_tag, _}, &1))) do
      {^string_tag, block} ->
        Logger.debug "Cabbage: Running tag @#{tag}..."
        state = evaluate_tag_block(block)
        start_state(scenario_name, module, state)
      _ ->
        nil # Nothing to do
    end
  end

  def map_tags(tags) do
    tags
    |> Enum.map(fn
      {tag, value} ->
        [{tag, value}]
      tag ->
        tag
    end)
  end
end
