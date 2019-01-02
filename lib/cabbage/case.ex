defmodule Cabbage.Case do
  @moduledoc """
  An extension on ExUnit to be able to execute feature files.

  ## Usage

  Features are expected to be located in `tests/features` folder (to change location see `Cabbage.Config`).

  Given you have `coffee.feature` file. Slightly more complex example as provided in [basic usage](https://hexdocs.pm/cabbage/readme.html)

  ```gherkin
  Feature: Serve coffee
    Coffee should not be served until paid for
    Coffee should not be served until the button has been pressed
    If there is no coffee left then money should be refunded

    Scenario: Buy last coffee
      Given there are 1 coffees left in the machine
      And I have deposited £1
      When I press the coffee button
      Then I should be served a coffee
  ```

  You create coresponding feature test case module which references `coffee.feature`.
  You don't have to define all steps at once. Cabbage will suggest missing steps implementations.

      defmodule MyApp.CoffeeTest do
        use Cabbage.Case, feature: "coffee.feature", async: false
      end

  When running `mix test` you will get error. Cabbage will not only tell you that step implementation is missing,
  but also suggest code for your missing step.
  It will try to guess regex, by providing named captures for numbers, and strings in single and double quotes.

      ** (Cabbage.MissingStepError) Please add a matching step for:
      "Given there are 1 coffees left in the machine"

        defgiven ~r/^there are (?<number_1>\\d+) coffees left in the machine$/, %{number_1: number_1}, state do
          # Your implementation here
        end

  Eventually filling all missing step implementations and providing logic for each of them

      defmodule Cabbage.CoffeeTest do
        use Cabbage.Case, feature: "coffee.feature", async: false

        defgiven ~r/^there are (?<count>\\d+) coffees left in the machine$/, %{count: count}, _state do
          {:ok, %{coffees_count: String.to_integer(count)}}
        end

        # Note that while in *.feature file step is defined as And, here it is definied with defgive
        defgiven ~r/^I have deposited £(?<amount>\\d+)$/, %{amount: amount}, _state do
          {:ok, %{money_amount: String.to_integer(amount)}}
        end

        defwhen ~r/^I press the coffee button$/, _vars, _state do
          {:ok, %{coffee_served: true}}
        end

        defthen ~r/^I should be served a coffee$/, _vars, state do
          assert state.coffees_count == 1
          assert state.money_amount == 1
          assert state.coffee_served == true
        end
      end

  This would rougly translate to

      defmodule Cabbage.CoffeeTest do
        use ExUnit.Case, async: false

        test "The name of the scenario here" do
          state = %{coffees_count: String.to_integer("1")}
          state = Map.merge(state, %{money_amount: String.to_integer("1")})
          state = Map.merge(state, %{coffee_served: true})

          assert state.coffees_count == 1
          assert state.money_amount == 1
          assert state.coffee_served == true
        end
      end

  Ofcourse this is trivial example, in real life you would call functions on modules you want to test.

  This provides the best of both worlds.
  Feature files for non-technical users, and an actual test file written in Elixir for developers that have to maintain them.

  ## Extracting data from step defninitions

  You’ll likely have data within your feature statements which you want to extract.

  The second parameter to each of `defgiven/4`, `defwhen/4` and `defthen/4` is named captures from step definition as map.
  For every named capture, you’ll have a key as an atom in the second parameter. You can then use those variables you create within your block.

      defgiven ~r/^there (is|are) (?<number>\\d+) widget(s?)$/, %{number: number}, _state do
        assert String.to_integer(number) >= 1
      end

  > Note that in this and previous example `String.to_integer/1` is used.
    Even though regex matches numbers, they still are passed in parameters as strings.
    If needed you can convert it using `String.to_integer/1` or `String.to_float/1`.

  ## Modifying state

  You’ll likely have to keep track of some state in between statements.
  The third parameter to each of `defgiven/4`, `defwhen/4` and `defthen/4` is a state map.
  The same way that the `ExUnit.Case.test/3` macro works.

  You can setup initial state using plain `ExUnit.Case.setup/1` and `ExUnit.Case.setup_all/1`.
  Whatever state is provided via the ` ExUnit.Case.test/3` macro will be your initial state.
  Or by using `setup_tag/3` for tag specifi setups/

  To update the state, simply return {:ok, %{new: :state}}.
  Note that a Map.merge/2 will be performed for you so only have to specify the keys you want to update.
  For this reason, only a map is allowed as state.

  Heres an example modifying state:

      defwhen ~r/^I am an admin$/, _, %{user: user} do
        {:ok, %{user: User.promote_to_admin(user)}}
      end

  ## Organizing Features

  You may want to reuse several statements you create, especially ones that deal with global logic like users and logging in.

  Feature modules can be created without referencing a feature file.
  This makes them do nothing except hold translations between steps in a scenario and test code to be included into a test.
  These modules must be compiled prior to running the test suite, so for that reason you must add them to the elixirc_paths in your `mix.exs` file, like so:

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

  If you’re using Phoenix, this should already be setup for you. Simply place a file like the following into test/support.

      defmodule MyApp.GlobalFeatures do
        use Cabbage.Feature

        # Write your defgiven/4, defthen/4, defwhen/4 and setup_tag/3
      end

  Then inside the test file (the .exs one) add a `import_feature MyApp.GlobalFeatures` line after the use Cabbage.Feature line lke so:

      defmodule MyApp.CoffeeTest do
        use Cabbage.Case, feature: "coffee.feature"
        import_feature MyApp.GlobalFeatures

        ...
      end

  Keep in mind that if you’d like to be more explicit about what you bring into your test,
  you can use the macros `import_steps/1` and `import_tags_setups/1`.
  This will allow you to be more selective about whats getting included into your integration tests.
  The `import_feature/1` macro simply calls both the `import_steps/1` and `import_tags/1` macros.

  ## Tables & Doc Strings

  Using tables and Doc Strings can be done easily, they are provided through the variables under the names `:table` and `:doc_string`.

  ```gherkin
  Feature: Can have complex features
    Test that can have advanced regular expression line matches and datatables

    Scenario: Can create scenario with dynamic key ingredients
      When I provide docs part
        \"\"\"
        Here is provided some complex part that is way to complex
        \"\"\"
      When I provide table part
        | Name | Age |
        | John | 30 |
        | Ann | 29 |
  ```

      defmodule FeatureExecutionTest4 do
        use Cabbage.Case, feature: "dynamic.feature"

        defwhen ~r/^When I provide docs part$/, %{doc_string: doc_string}, _state do
          assert table == "Here is provided some complex part that is way to complex"
        end

        defwhen ~r/^When I provide table part$/, %{table: table}, _state do
          assert table == [%{Age: "30", Name: "John"}, %{Age: "29", Name: "Ann"}]
        end
      end
  """

  # ## Running specific tests
  #
  # Typically to run an ExUnit test you would do something like `mix test test/some_test.exs:12` and elixir will automatically load  `test/some_test.exs` for you, but only run the test on line `12`. Since the feature files are being translated into ExUnit at compile time, you'll have to specify the `.exs` file and not the `.feature` file to run. The line numbers are printed out as each test runs (at the `:info` level, so you may need to increase your logger config if you dont see anything). An example is like as follows:
  #
  #     # Runs scenario of test/features/coffee.feature on line 13
  #     mix test test/feature_test.exs:13

  alias Cabbage.{Loader, Config, FeaturesManager, SetupsManager, StepsManager}
  alias Macro.Env

  defmacro __using__(options), do: using(__CALLER__, options)
  defmacro __before_compile__(env), do: before_compile(env)

  @doc """
  Registers `given` step callback.

      defgiven ~r/Regex goes here/, _matched_data, _test_state do
        # Your implementation here
      end
  """
  defmacro defgiven(regex, parameters, state, do: block) do
    register_step_callback(__CALLER__, :given, regex, parameters, state, block)
  end

  @doc """
  Registers `when` step callback.

      defwhen ~r/Regex goes here/, _matched_data, _test_state do
        # Your implementation here
      end
  """
  defmacro defwhen(regex, parameters, state, do: block) do
    register_step_callback(__CALLER__, :when, regex, parameters, state, block)
  end

  @doc """
  Registers `then` step callback.

      defthen ~r/Regex goes here/, _matched_data, _test_state do
        # Your implementation here
      end
  """
  defmacro defthen(regex, parameters, state, do: block) do
    register_step_callback(__CALLER__, :then, regex, parameters, state, block)
  end

  @doc """
  Add an `ExUnit.Case.setup/1` callback that only fires for the scenarios that are tagged.

      setup_tag @tag, _test_state do
        # Your implementation here
      end
  """
  defmacro setup_tag(tag, state, do: block) do
    register_tag_callback(__CALLER__, tag, state, block)
  end

  @doc """
  Import defined steps from other module that uses `Cabbage.Case`.
  """
  defmacro import_steps(module) do
    import_from_other_feature(__CALLER__, module, [:steps])
  end

  @doc """
  Import defined tag setups from other module that uses `Cabbage.Case`.
  """
  defmacro import_tags_setups(module) do
    import_from_other_feature(__CALLER__, module, [:setups])
  end

  @doc """
  Import both step and setup definitions from other module that uses `Cabbage.Case`.
  """
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

      use unquote(Config.test_case(options)), unquote(Config.test_case_options(options))
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

    if Config.has_feature?(options) do
      steps_callbacks = Module.get_attribute(env.module, :steps) |> Enum.reverse()
      setups_callbacks = Module.get_attribute(env.module, :setups) |> Enum.reverse()

      options
      |> Config.feature_path()
      |> Loader.load_from_file()
      |> FeaturesManager.prepare_scenarios(options)
      |> Enum.map(&register_test(&1, {setups_callbacks, steps_callbacks}, env))
    end
  end

  defp register_test(scenario, {setups, steps}, %Env{} = env) do
    env = %{env | line: scenario.line}
    tags = SetupsManager.normalize_tags_for_test(scenario.tags)
    name = ExUnit.Case.register_test(env, :test, scenario.name, tags)

    quote do
      def unquote(name)(state) do
        state = Enum.reduce(unquote(scenario.tags), state, &SetupsManager.execute(&1, &2, unquote(setups)))

        Enum.reduce(unquote(Macro.escape(scenario.steps)), state, &StepsManager.execute(&1, &2, unquote(steps)))
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
          with true <- SetupsManager.are_tags_equal?(unquote(tag), executing_tag),
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
