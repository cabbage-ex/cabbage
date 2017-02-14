# Cabbage

<img src="https://www.organicfacts.net/wp-content/uploads/2013/12/redcabbage.jpg" width="240px" height="180px"></img>
##### (Looking contribution for a better icon!)

A simple addon on top of [ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html) which provides compile time translation of `.feature` files to exunit tests. Big thanks to [@meadsteve](https://github.com/meadsteve) and the [White Bread](https://github.com/meadsteve/white-bread) project for a huge head start on this project.

## NOTE: Basic features are available, but project is still under development!

## Installation

[Available in Hex](https://hex.pm/packages/cabbage), the package can be installed as:

  1. Add `cabbage` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:cabbage, "~> 0.1.0"}]
    end
    ```

## Example Usage

Inside `test/features/coffee.feature` you might have something like:

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

To translate this to a simple exunit test, all you need to do is provide the translation of lines to steps in the test. Inside `test/features/coffee_test.exs` (or anywhere you like really).

```elixir
defmodule MyApp.Features.CoffeeTest do
  # Base directory of features is configurable, assumes "test/features/" is prepended
  # remaining options are passed directly to `ExUnit`
  use Cabbage.Feature, async: false, file: "coffee.feature"

  # `setup_all/1` provides a callback for doing something before the entire suite runs
  # As below, `setup/1` provides means of doing something prior to each scenario
  setup do
    on_exit fn -> # Do something when the scenario is done
      IO.puts "Scenario completed, cleanup stuff"
    end
    {:ok, %{my_starting: :state, user: %User{}}} # Return some beginning state
  end

  # All `defgiven/4`, `defand/4`, `defwhen/4` and `defthen/4` takes a regex, matched data, state and lastly a block
  defgiven ~r/^there (is|are) (?<number>\d+) coffee(s) left in the machine$/, %{user: user}, %{number: number} do
    # `{:ok, state}` gets returned from each callback which updates the state or
    # leaves the state unchanged when something else is returned
    {:ok, %{machine: Machine.put_coffee(Machine.new, number)}}
  end

  defand ~r/^And I have deposited £(?<number>\d+)$/, %{user: user, machine: machine}}, %{number: number} do
    {:ok, %{machine: Machine.deposit(machine, user, number)}} # State is automatically merged so this won't erase `user`
  end

  # With no matches, the map is empty. Since state is unchanged, its not necessary to return it
  defwhen ~r/^I press the coffee button$/, state, %{} do
    Machine.press_coffee(state.machine) # instead would be some `hound` or `wallaby` dsl
  end

  # Since state is unchanged, its not necessary to return it
  defthen ~r/^I should be served a coffee$/, state, _ do
    assert %Coffee{} = Machine.take_drink(state.machine) # Make your `assert`ions in `defthen/4`s and `defand/4`s
  end
end
```

The resulting compiled test will be logically equivalent to:

```elixir
defmodule MyApp.Features.CoffeeTest do
  use ExUnit.Case, async: false

  setup do
    on_exit fn ->
      IO.puts "Scenario completed, cleanup stuff"
    end
    {:ok, %{my_starting: :state, user: %User{}}}
  end

  # Each scenario would generate a single test case
  @tag :integration
  test "Buy last coffee", %{my_starting: :state, user: user} do
    # From the given
    state = %{user: user, machine: Machine.put_coffee(Machine.new, number)}
    # From the and
    state = Map.put(state, :machine, Machine.deposit(machine, user, number))
    # From the when
    Machine.press_coffee(state.machine)
    # From the then
    assert %Coffee{} = Machine.take_drink(state.machine)
  end
end
```

This provides the best of both worlds. Feature files for non-technical users, and an actual test file written in Elixir for developers that have to maintain them.

# Roadmap

- [x] Scenarios
- [x] Scenario Outlines
- [ ] Tags implementation
- [ ] Integration Helpers for Wallaby (separate project?)
- [ ] Integration Helpers for Hound (separate project?)
