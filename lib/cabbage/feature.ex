defmodule Cabbage.Feature do
  @moduledoc """
  """

  @feature_opts [:file]
  defmacro __using__(opts) do
    {opts, exunit_opts} = Keyword.split(opts, @feature_opts)
    is_feature = !match?(nil, opts[:file])
    quote location: :keep do
      unquote(if is_feature do
        quote do
          @before_compile unquote(__MODULE__)
          use ExUnit.Case, unquote(exunit_opts)
        end
      end)
      @before_compile {unquote(__MODULE__), :expose_steps}
      import unquote(__MODULE__)
      require Logger

      Module.register_attribute(__MODULE__, :steps, accumulate: true)

      unquote(if is_feature do
        quote do
          @feature File.read!("#{Cabbage.base_path}#{unquote(opts[:file])}") |> Gherkin.Parser.parse_feature()
          @scenarios @feature.scenarios
        end
      end)
    end
  end

  defmacro expose_steps(env) do
    steps = Module.get_attribute(env.module, :steps)
    quote generated: true do
      def raw_steps() do
        unquote(Macro.escape(steps))
      end
    end
  end

  defmacro __before_compile__(env) do
    scenarios = Module.get_attribute(env.module, :scenarios) || []
    steps = Module.get_attribute(env.module, :steps) || []
    for scenario <- scenarios do
      quote location: :keep, generated: true do
        @tag :integration
        test unquote(scenario.name), exunit_state do
          Agent.start(fn -> exunit_state end, name: unquote(agent_name(scenario.name)))
          Logger.info ["\t", IO.ANSI.magenta, "Scenario: ", IO.ANSI.yellow, unquote(scenario.name)]
          unquote Enum.map(scenario.steps, &execute(&1, steps, scenario.name))
        end
      end
    end
  end

  def execute(step, steps, scenario_name) when is_list(steps) do
    step_type = Module.split(step.__struct__) |> List.last()
    case Enum.find(steps, fn ({:{}, _, [r, _, _, _]}) -> step.text =~ Code.eval_quoted(r) |> elem(0) end) do
      {:{}, _, [regex, vars, state_pattern, block]} ->
        {regex, _} = Code.eval_quoted(regex)
        named_vars = for {key, val} <- Regex.named_captures(regex, step.text), into: %{}, do: {String.to_atom(key), val}
        quote location: :keep, generated: true do
          state = Agent.get(unquote(agent_name(scenario_name)), &(&1))
          unquote(vars) = unquote(Macro.escape(named_vars))
          unquote(state_pattern) = state
          new_state = case unquote(block) do
                        {:ok, new_state} -> Map.merge(new_state, state)
                        _ -> state
                      end
          Agent.update(unquote(agent_name(scenario_name)), fn(_) -> new_state end)
          Logger.info ["\t\t", IO.ANSI.cyan, unquote(step_type), " ", IO.ANSI.green, unquote(step.text)]
        end
      _ ->
        raise """

        Please add a matching step for:
        "#{step_type} #{step.text}"

          def#{step_type |> String.downcase} ~r/^#{step.text}$/, vars, state do
            # Your implementation here
          end
        """
    end
  end

  defmacro import_feature(module) do
    quote do
      if Code.ensure_compiled?(unquote(module)) do
        for step <- unquote(module).raw_steps() do
          Module.put_attribute(__MODULE__, :steps, step)
        end
      end
    end
  end

  defmacro defgiven(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block)
  end

  defmacro defand(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block)
  end

  defmacro defwhen(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block)
  end

  defmacro defthen(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block)
  end

  defp add_step(module, regex, vars, state, block) do
    steps = Module.get_attribute(module, :steps) || []
    Module.put_attribute(module, :steps, [{:{}, [], [regex, vars, state, block]} | steps])
    quote(do: nil)
  end

  defp agent_name(scenario_name) do
    :"cabbage_integration_test-#{scenario_name}"
  end
end
