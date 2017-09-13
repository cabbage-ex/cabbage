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

  Keep in mind that if you'd like to be more explicit about what you bring into your test, you can use the macros `import_steps/1` and `import_tags/1`. This will allow you to be more selective about whats getting included into your integration tests. The `import_feature/1` macro simply calls both the `import_steps/1` and `import_tags/1` macros.
  """
  import Cabbage.Feature.Helpers

  @feature_opts [:file, :template]
  defmacro __using__(opts) do
    {opts, exunit_opts} = Keyword.split(opts, @feature_opts)
    is_feature = !match?(nil, opts[:file])
    quote do
      unquote(if is_feature do
        quote do
          @before_compile unquote(__MODULE__)
          use unquote(opts[:template] || ExUnit.Case), unquote(exunit_opts)
        end
      end)
      @before_compile {unquote(__MODULE__), :expose_metadata}
      import unquote(__MODULE__)
      require Logger

      Module.register_attribute(__MODULE__, :steps, accumulate: true)
      Module.register_attribute(__MODULE__, :tags, [])

      unquote(if is_feature do
        quote do
          @feature File.read!("#{Cabbage.base_path}#{unquote(opts[:file])}") |> Gherkin.parse() |> Gherkin.flatten()
          @scenarios @feature.scenarios
        end
      end)
    end
  end

  defmacro expose_metadata(env) do
    steps = Module.get_attribute(env.module, :steps) || []
    tags = Module.get_attribute(env.module, :tags) || []
    quote generated: true do
      def raw_steps() do
        unquote(Macro.escape(steps))
      end
      def raw_tags() do
        unquote(Macro.escape(tags))
      end
    end
  end

  defmacro __before_compile__(env) do
    scenarios = Module.get_attribute(env.module, :scenarios) || []
    steps = Module.get_attribute(env.module, :steps) || []
    tags = Module.get_attribute(env.module, :tags) || []
    test_number = 0


    Enum.with_index(scenarios) |> Enum.each(fn {scenario, test_number} ->
      quote generated: true do
        describe "#{unquote test_number}. #{unquote scenario.name}" do
          @scenario unquote(Macro.escape(scenario))
          setup context do
            for tag <- unquote(scenario.tags) do
              case Enum.find(unquote(Macro.escape(tags)), &(match?({^tag, _}, &1))) do
                {^tag, block} ->
                  Logger.debug "Cabbage: Running tag @#{tag}..."
                  state = Cabbage.Feature.Helpers.evaluate_tag_block(block)
                  Cabbage.Feature.Helpers.start_state(unquote(scenario.name), __MODULE__, state)
                _ ->
                  Logger.warn "Cabbage: Ignoring tag @#{tag}!"
              end
            end
            {:ok, Map.merge(Cabbage.Feature.Helpers.fetch_state(unquote(scenario.name), __MODULE__), context || %{})}
          end

          ExUnit.Case.register_test(unquote(Macro.escape(%{env | line: scenario.line})), :test, unquote(scenario.name), [])
          @tag :integration
          def unquote(:"test #{scenario.name} (#{test_number}) #{scenario.name}")(exunit_state) do
            Cabbage.Feature.Helpers.start_state(unquote(scenario.name), __MODULE__, exunit_state)
            Logger.info [IO.ANSI.color(61), "Line ", to_string(unquote(scenario.line)), ":  ", IO.ANSI.magenta, "Scenario: ", IO.ANSI.yellow, unquote(scenario.name)]
            unquote Enum.map(scenario.steps, &compile_step(&1, steps, scenario.name))
          end
        end
      end
    end
  end

  def compile_step(step, steps, scenario_name) when is_list(steps) do
    step_type =
      step.__struct__
      |> Module.split()
      |> List.last()

    step
    |> find_implementation_of_step(steps)
    |> compile(step, step_type, scenario_name)
  end

  defp compile({:{}, _, [regex, vars, state_pattern, block, metadata]}, step, step_type, scenario_name) do
    {regex, _} = Code.eval_quoted(regex)
    named_vars = extract_named_vars(regex, step.text) |> Map.merge(%{table: step.table_data, doc_string: step.doc_string})
    quote generated: true do
      with {_type, unquote(vars)} <- {:variables, unquote(Macro.escape(named_vars))},
           {_type, state = unquote(state_pattern)} <- {:state, Cabbage.Feature.Helpers.fetch_state(unquote(scenario_name), __MODULE__)}
           do
        new_state = case unquote(block) do
                      {:ok, new_state} -> Map.merge(state, new_state)
                      _ -> state
                    end
        Cabbage.Feature.Helpers.update_state(unquote(scenario_name), __MODULE__, fn(_) -> new_state end)
        Logger.info ["\t\t", IO.ANSI.cyan, unquote(step_type), " ", IO.ANSI.green, unquote(step.text)]
      else
        {type, state} ->
          metadata = unquote(Macro.escape(metadata))
          reraise """
          ** (MatchError) Failure to match #{type} of #{inspect Cabbage.Feature.Helpers.remove_hidden_state(state)}
          Pattern: #{unquote(Macro.to_string(state_pattern))}
          """, Cabbage.Feature.Helpers.stacktrace(__MODULE__, metadata)
      end
    end
  end

  defp compile(_, step, step_type, _scenario_name) do
    raise MissingStepError, [step_text: step.text, step_type: step_type]
  end

  defp find_implementation_of_step(step, steps) do
    Enum.find(steps, fn ({:{}, _, [r, _, _, _, _]}) ->
      step.text =~ r |> Code.eval_quoted() |> elem(0)
    end)
  end

  defp extract_named_vars(regex, step_text) do
    regex
    |> Regex.named_captures(step_text)
    |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
    |> Enum.into(%{})
  end

  @doc """
  Brings in all the functionality available from the supplied module. Module must `use Cabbage.Feature` (with or without a `:file`).

  Same as calling both `import_steps/1` and `import_tags/1`.
  """
  defmacro import_feature(module) do
    quote do
      import_steps(unquote(module))
      import_tags(unquote(module))
    end
  end

  @doc """
  Brings in all the step definitions from the supplied module. Module must `use Cabbage.Feature` (with or without a `:file`).
  """
  defmacro import_steps(module) do
    quote do
      if Code.ensure_compiled?(unquote(module)) do
        for step <- unquote(module).raw_steps() do
          Module.put_attribute(__MODULE__, :steps, step)
        end
      end
    end
  end

  @doc """
  Brings in all the tag definitions from the supplied module. Module must `use Cabbage.Feature` (with or without a `:file`).
  """
  defmacro import_tags(module) do
    quote do
      if Code.ensure_compiled?(unquote(module)) do
        for {name, block} <- unquote(module).raw_tags() do
          Cabbage.Feature.Helpers.add_tag(__MODULE__, name, block)
        end
      end
    end
  end

  defmacro defgiven(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block, metadata(__CALLER__, :defgiven))
  end

  defmacro defand(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block, metadata(__CALLER__, :defand))
  end

  defmacro defwhen(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block, metadata(__CALLER__, :defwhen))
  end

  defmacro defthen(regex, vars, state, [do: block]) do
    add_step(__CALLER__.module, regex, vars, state, block, metadata(__CALLER__, :defthen))
  end

  @doc """
  Add an ExUnit `setup/1` callback that only fires for the scenarios that are tagged. Can be
  used inside of `Cabbage.Feature`s that don't relate to a file and then imported with `import_feature/1`.

  Example usage:

      defmodule MyTest do
        use Cabbage.Feature

        tag @some_tag do
          IO.puts "Do this before the @some_tag scenario"
          on_exit fn ->
            IO.puts "Do this after the @some_tag scenario"
          end
        end
      end
  """
  defmacro tag(tag, [do: block]) do
    add_tag(__CALLER__.module, Macro.to_string(tag) |> String.replace(~r/\s*/, ""), block)
  end
end
