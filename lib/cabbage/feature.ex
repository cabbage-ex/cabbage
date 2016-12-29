defmodule Cabbage.Feature do
  @moduledoc """
  An extension on ExUnit to be able to execute feature files.

  ## Configuration

  In `config/test.exs`

      config :cabbage,
        # Default is "test/features/"
        features: "my/path/to/features/"

  Allows you to specify the location of your feature files. They can be anywhere, but typically are located within the test folder.

  ## Features

  Given a feature file, create a corresponding feature module which references it. Heres an example:

      defmodule MyApp.SomeFeatureTest do
        use Cabbage.Feature, file: "some_feature.feature"

        defgiven ~r/I am given a given statement/, _matched_data, _current_state do
          assert 1 + 1 == 2
          {:ok, %{new: :state}}
        end

        defwhen ~r/I when execute it/, _matched_data, _current_state do
          # Nothing to do, don't need to return anything if we don't want to
          nil
        end

        defthen ~r/everything is ok/, _matched_data, _current_state do
          assert true
        end
      end

  This translates loosely into:

      defmodule MyApp.SomeFeatureTest do
        use ExUnit.Case

        test "The name of the scenario here" do
          assert 1 + 1 == 2
          nil
          assert true
        end
      end

  ### Extracting Matched Data

  You'll likely have data within your feature statements which you want to extract. The second parameter to each of `defgiven/4`, `defwhen/4`, `defthen/4` and `defand/4` is a pattern in which specifies what you want to call the matched data, provided as a map.

  For example, if you want to match on a number:

      # NOTICE THE `number` VARIABLE IS STILL A STRING!!
      defgiven ~r/^there (is|are) (?<number>\d+) widget(s?)$/, %{number: number}, _state do
        assert String.to_integer(number) >= 1
      end

  For every named capture, you'll have a key as an atom in the second parameter. You can then use those variables you create within your block.

  ### Modifying State

  You'll likely have to keep track of some state in between statements. The third parameter to each of `defgiven/4`, `defwhen/4`, `defthen/4` and `defand/4` is a pattern in which specifies what you want to call your state in the same way that the `ExUnit.Case.test/3` macro works.

  You can setup initial state using plain ExUnit `setup/1` and `setup_all/1`. Whatever state is provided via the `test/3` macro will be your initial state.

  To update the state, simply return `{:ok, %{new: :state}}`. Note that a `Map.merge/2` will be performed for you so only have to specify the keys you want to update. For this reason, only a map is allowed as state.

  Heres an example modifying state:

      defand ~r/^I am an admin$/, _, %{user: user} do
        {:ok, %{user: User.promote_to_admin(user)}}
      end

  All other statements do not need to return (and should be careful not to!) the `{:ok, state}` pattern.

  ### Organizing Features

  You may want to reuse several statements you create, especially ones that deal with global logic like users and logging in.

  Feature modules can be created without referencing a file. This makes them do nothing except hold translations between steps in a scenario and test code to be included into a test. These modules must be compiled prior to running the test suite, so for that reason you must add them to the `elixirc_paths` in your `mix.exs` file, like so:

      defmodule MyApp.Mixfile do
        use Mix.Project

        def project do
          [
            app: :my_app,
            ... # Add this to your project function
            elixirc_paths: elixirc_paths(Mix.env),
            ...
          ]
        end

        # Specifies which paths to compile per environment.
        defp elixirc_paths(:test), do: ["lib", "test/support"]
        defp elixirc_paths(_),     do: ["lib"]

        ...
      end

  If you're using Phoenix, this should already be setup for you. Simply place a file like the following into `test/support`.

      defmodule MyApp.GlobalFeatures do
        use Cabbage.Feature

        # Write your `defgiven/4`, `defthen/4`, `defwhen/4` and `defand/4`s here
      end

  Then inside the test file (the .exs one) add a `import_feature MyApp.GlobalFeatures` line after the `use Cabbage.Feature` line lke so:

      defmodule MyApp.SomeFeatureTest do
        use Cabbage.Feature, file: "some_feature.feature"
        import_feature MyApp.GlobalFeatures

        # Omitted the rest
      end
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
          @feature File.read!("#{Cabbage.base_path}#{unquote(opts[:file])}") |> Gherkin.parse()
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
