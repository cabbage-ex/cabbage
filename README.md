# Cabbage

[![CI](https://github.com/tomasz-tomczyk/cabbage/actions/workflows/ci.yml/badge.svg)](https://github.com/tomasz-tomczyk/cabbage/actions/workflows/ci.yml)

A spec-conformant [Cucumber](https://cucumber.io/) runner for Elixir.

Cabbage compiles Gherkin `.feature` files into [ExUnit](https://hexdocs.pm/ex_unit/ExUnit.html)
tests at compile time, so non-technical stakeholders read and write the feature files while
developers maintain ordinary Elixir step definitions. It parses Gherkin with the
[gherkin fork](https://github.com/tomasz-tomczyk/gherkin) and also ships a message-emitting
interpreter that is graded against the official Cucumber test kits.

## Example Usage

By default, feature files are expected inside `test/features`. This can be configured within
your application:

```elixir
config :cabbage, features: "some/other/path/from/your/project/root"
```

Inside `test/features/coffee.feature`:

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

Steps that recur across features go in a shared `Cabbage.Steps` library (a module
that defines no tests). Inside `test/support/coffee_steps.ex`:

```elixir
defmodule MyApp.CoffeeSteps do
  use Cabbage.Steps

  # A string Cucumber Expression binds its matched data as a positional *list* of
  # already-transformed arguments — here `{int}` arrives as an integer, not a string.
  # (To match a literal `{`, escape it: `"\\{weird\\}"` matches the text `{weird}`.)
  defstep "there are {int} coffees left in the machine", [count], _ctx do
    {:ok, %{machine: Machine.put_coffee(Machine.new(), count)}}
  end
end
```

The per-feature module `use`s `Cabbage.Feature`, imports the shared library, and
defines its local steps. Inside `test/features/coffee_test.exs`:

```elixir
defmodule MyApp.Features.CoffeeTest do
  # Options other than `:file`/`:import` are passed directly to ExUnit.
  use Cabbage.Feature, async: true, file: "coffee.feature", import: [MyApp.CoffeeSteps]

  # `setup/1` runs before each scenario; its return value is the initial context.
  setup do
    %{user: %User{}}
  end

  # A regex binds its matched data as a *map* of named captures (string values).
  defgiven ~r/^I have deposited £(?<amount>\d+)$/, %{amount: amount}, %{user: user, machine: machine} do
    {:ok, %{machine: Machine.deposit(machine, user, String.to_integer(amount))}}
  end

  defwhen "I press the coffee button", _vars, ctx do
    Machine.press_coffee(ctx.machine)
  end

  defthen "I should be served a coffee", _vars, ctx do
    assert %Coffee{} = Machine.take_drink(ctx.machine)
  end
end
```

The compiled test is logically equivalent to a hand-written ExUnit case: each scenario
becomes one `test`, with the context threaded from step to step. This gives the best of
both worlds: feature files for non-technical stakeholders, and a real Elixir test file
for the developers who maintain them.

### Steps match by pattern, not keyword

A step matches a feature line by its **pattern only** — the `Given`/`When`/`Then`/`And`/`But`
keyword is never part of matching. `defstep` is the canonical, keyword-neutral macro;
`defgiven`/`defwhen`/`defthen`/`defand`/`defbut` are readability aliases that register
identically. A `defstep` can match a `Given` line and a `defgiven` can match a `Then` line.

### State contract

A step's return value drives the context threaded to the next step:

| Return value       | Effect on the context                                  |
| ------------------ | ------------------------------------------------------ |
| `:ok` or `nil`     | context unchanged                                      |
| `{:ok, map}`       | `Map.merge(context, map)` — delta-merge (recommended)  |
| a bare `map`       | **replaces** the context with that map                 |
| `{:error, reason}` | the step fails (raises, naming the step and reason)    |
| anything else      | the step fails (raises, naming the step and the value) |

`{:ok, %{...}}` is the everyday form — add or change just the keys you name. A bare map
is the whole-world form — it replaces the entire context (use it to reset state). The
context must be a plain map; returning a struct (bare or `{:ok, struct}`) raises. A
non-conforming return no longer silently keeps the context, so a step can never quietly
no-op a state update.

### Tables & Doc Strings

A step's gherkin **data table** and **doc string** are reachable from the context under
the reserved keys `ctx.__table__` and `ctx.__doc_string__` (the empty list / empty string
when absent). They are injected per step and never threaded forward.

```elixir
defwhen "I submit:", _vars, ctx do
  {:ok, %{submitted: ctx.__table__}}
end
```

See the dynamic-data example in
[test/feature_execution_test.exs](test/feature_execution_test.exs) and
[test/features/dynamic.feature](test/features/dynamic.feature).

### Running specific tests

Feature files are translated to ExUnit at compile time, so target the `.exs` file (not the
`.feature` file) when running a single scenario. The line numbers are printed as each test runs.

```shell
# Runs the scenario of test/features/coffee.feature compiled into feature_test.exs at line 13
mix test test/feature_test.exs:13
```

### Emitting cucumber-messages

`Cabbage.Formatter` is an ExUnit formatter that writes a
[cucumber-messages](https://github.com/cucumber/messages) NDJSON stream as your scenarios
run. Add it alongside the default formatter in `test/test_helper.exs`:

```elixir
ExUnit.start(formatters: [ExUnit.CLIFormatter, Cabbage.Formatter])
```

The stream is written to `cucumber-messages.ndjson` by default; configure the path with
`config :cabbage, messages_output: "path.ndjson"` or the formatter's `:messages_output`
option. See `Cabbage.Formatter` for the emitted envelope types and the scenario-level
step-result semantics.

## Installation

Add `cabbage` to your dependencies in `mix.exs`, pointing at this fork:

```elixir
def deps do
  [
    {:cabbage, github: "tomasz-tomczyk/cabbage", branch: "master"}
  ]
end
```

> The Hex package and OTP application name remain `:cabbage`; a rename is deferred to a
> later release so existing dependents keep resolving.

## Conformance

This fork is verified against the upstream Cucumber suites:

| Suite | Score |
| --- | --- |
| Cucumber Compatibility Kit (CCK) | **43 / 44** |
| Cucumber Expressions | **115 / 115** |
| Tag Expressions | **64 / 64** |

The scoreboards are reproducible locally:

```shell
MIX_ENV=test mix conformance.cck
MIX_ENV=test mix conformance.tags
MIX_ENV=test mix conformance.expressions
```

These tasks print scoreboards. The hard regression gate (run in CI) is the tagged ExUnit
suite, which asserts the expected passing-sample sets:

```shell
mix test --only conformance
```

## Developing

Run the test suite and the conformance gates:

```shell
mix deps.get
mix test
mix test --only conformance
```

A `docker-compose.yml` is also provided for running the tests in containers:

```shell
docker-compose up
```
