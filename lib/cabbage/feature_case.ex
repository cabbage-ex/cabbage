defmodule Cabbage.FeatureCase do
  alias Cabbage.Feature.{Loader, OptionsManager, StepsManager, TestRunner}
  alias Gherkin.Elements.{Feature, Scenario}
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

  defp using(env, options) do
    Module.register_attribute(env.module, :steps, accumulate: true)
    Module.put_attribute(env.module, :options, options)

    quote do
      @before_compile unquote(__MODULE__)
      import unquote(__MODULE__), only: [defgiven: 4, defwhen: 4, defthen: 4]
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

    quote generated: true do
      def steps(), do: unquote(steps)
    end
  end

  defp register_feature_tests(%Env{} = env) do
    options = Module.get_attribute(env.module, :options)

    if OptionsManager.has_feature?(options) do
      options
      |> OptionsManager.feature()
      |> Loader.load_from_file()
      |> register_feature_tests(env)
    end
  end

  defp register_feature_tests(%Feature{} = feature, %Env{} = env) do
    implemented_steps = Module.get_attribute(env.module, :steps) |> Enum.reverse()

    feature
    |> Map.get(:scenarios, [])
    |> Enum.map(&register_scenario_test(&1, implemented_steps, env))
  end

  defp register_scenario_test(%Scenario{} = scenario, implemented_steps, %Env{} = env) do
    env = %{env | line: scenario.line}
    name = ExUnit.Case.register_test(env, :test, scenario.name, scenario.tags)

    quote do
      def unquote(name)(test_state) do
        TestRunner.run_scenario(
          unquote(Macro.escape(scenario)),
          unquote(implemented_steps),
          test_state
        )
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
end
