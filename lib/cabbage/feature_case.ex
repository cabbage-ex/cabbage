defmodule Cabbage.FeatureCase do
  alias Cabbage.{CallbacksExecutor, Loader, OptionsManager, StepsManager}
  alias Gherkin.Elements.Scenario
  alias Macro.Env

  defmacro __using__(options), do: using(__CALLER__, options)
  defmacro __before_compile__(env), do: before_compile(env)

  defmacro defgiven(regex, parameters, state, do: block) do
    register_step_callback(__CALLER__, :given, regex, parameters, state, block)
  end

  defmacro defwhen(regex, parameters, state, do: block) do
    register_step_callback(__CALLER__, :when, regex, parameters, state, block)
  end

  defmacro defthen(regex, parameters, state, do: block) do
    register_step_callback(__CALLER__, :then, regex, parameters, state, block)
  end

  defmacro setup_tag(tag, state, do: block) do
    register_tag_callback(__CALLER__, tag, state, block)
  end

  defmacro import_steps(module) do
    import_from_other_feature(__CALLER__, module, [:steps])
  end

  defmacro import_tags_setups(module) do
    import_from_other_feature(__CALLER__, module, [:setups])
  end

  defmacro import_feature(module) do
    import_from_other_feature(__CALLER__, module, [:steps, :setups])
  end

  defp using(env, options) do
    Module.register_attribute(env.module, :steps, accumulate: true)
    Module.register_attribute(env.module, :setups, accumulate: true)
    Module.put_attribute(env.module, :options, [{:env, env} | options])

    quote do
      @before_compile unquote(__MODULE__)
      import unquote(__MODULE__)

      use unquote(OptionsManager.test_case(options))
    end
  end

  defp before_compile(env) do
    quote do
      unquote(register_raw_data_callbacks(env))
      unquote(register_feature_tests(env))
    end
  end

  defp register_raw_data_callbacks(env) do
    steps = env.module |> Module.get_attribute(:steps) |> Macro.escape()
    tags = env.module |> Module.get_attribute(:setups) |> Macro.escape()

    quote generated: true do
      def steps(), do: unquote(steps)
      def setups(), do: unquote(tags)
    end
  end

  defp register_feature_tests(%Env{} = env) do
    options = Module.get_attribute(env.module, :options)

    if OptionsManager.has_feature?(options) do
      feature =
        options
        |> OptionsManager.feature_path()
        |> Loader.load_from_file()

      implemented_steps = Module.get_attribute(env.module, :steps) |> Enum.reverse()
      implemented_setups = Module.get_attribute(env.module, :setups) |> Enum.reverse()

      feature.scenarios
      |> Enum.map(&%{&1 | tags: OptionsManager.tags(options, &1.tags)})
      |> Enum.map(&register_scenario_test(&1, feature, {implemented_setups, implemented_steps}, env))
    end
  end

  defp register_scenario_test(%Scenario{} = scenario, _feature, {setups, steps}, %Env{} = env) do
    env = %{env | line: scenario.line}
    name = ExUnit.Case.register_test(env, :test, scenario.name, scenario.tags)

    quote do
      def unquote(name)(state) do
        state = CallbacksExecutor.execute_setups_callbacks(unquote(scenario.tags), state, unquote(setups))
        _state = CallbacksExecutor.execute_tests_callbacks(unquote(Macro.escape(scenario.steps)), state, unquote(steps))
      end
    end
  end

  defp register_step_callback(env, type, regex, parameters_pattern, state_pattern, block) do
    callback =
      quote generated: true do
        fn step, test_state ->
          with true <- StepsManager.handles_step?({unquote(type), unquote(regex)}, step),
               unquote(parameters_pattern) <- StepsManager.extract_parameters(unquote(regex), step),
               unquote(state_pattern) <- test_state do
            unquote(block)
          else
            _ -> {:error, :no_match}
          end
        end
      end

    Module.put_attribute(env.module, :steps, callback)
  end

  defp register_tag_callback(env, tag, state_pattern, block) do
    {_, [_], [{tag, [_], _}]} = tag

    callback =
      quote generated: true do
        fn executing_tag, test_state ->
          with ^executing_tag <- unquote(tag),
               unquote(state_pattern) <- test_state do
            unquote(block)
          else
            _ -> {:error, :no_match}
          end
        end
      end

    Module.put_attribute(env.module, :setups, callback)
  end

  defp import_from_other_feature(env, modules, fields) when is_list(modules) do
    Enum.each(modules, &import_from_other_feature(env, &1, fields))
  end

  defp import_from_other_feature(env, module, fields) do
    quote do
      if Code.ensure_compiled?(unquote(module)) do
        unquote(fields)
        |> Enum.each(fn field ->
          unquote(module)
          |> apply(field, [])
          |> Enum.each(fn value ->
            Module.put_attribute(unquote(Macro.escape(env.module)), field, value)
          end)
        end)
      end
    end
  end
end
