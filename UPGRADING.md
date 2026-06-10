# Upgrading cabbage 0.4.1 → 1.0.0

**The headline: most step-definition code compiles unchanged.** The macro API
you already use (`use Cabbage.Feature`, `defgiven/defwhen/defthen`,
`import_feature/import_steps/import_tags`, `tag`) is all retained, and the
everyday `{:ok, map}` merge return still works. The 1.0.0 internals are a
ground-up rewrite onto a spec-conformant Gherkin pipeline, so most of what you may
need to touch is your **versions** and your **`.feature` files**.

The **one behavioural change to audit in your Elixir steps** is the state
contract: a step that relied on the old contract *silently keeping* state when it
returned a non-conforming value now raises. See [State contract](#state-contract)
below. New features are additive: `defstep` plus keyword-agnostic matching, and
`Cabbage.Steps` for sharing steps.

## What you must change

### 1. Toolchain / dependency versions

- **Elixir** must be `~> 1.18` (Cabbage now uses the built-in `JSON` module).
- **gherkin** must be `~> 3.0` (the rewritten pipeline). Update both in your
  `mix.exs`:

  ```elixir
  def project do
    [
      elixir: "~> 1.18",
      # ...
    ]
  end

  defp deps do
    [
      {:cabbage, "~> 1.0"}
      # gherkin ~> 3.0 comes in transitively
    ]
  end
  ```

  Then `mix deps.get`.

### 2. Remove non-standard "valued" tags from `.feature` files

Tags like `@timeout 100` were never valid Gherkin and are now **rejected** with
a parse error. Find them:

```sh
grep -rnE '^\s*@[A-Za-z0-9_]+\s+\S' features/
```

Rewrite each as a plain tag, optionally moving the value elsewhere:

```diff
- @timeout 100
+ @slow
  Scenario: ...
```

…and handle `@slow` in your step/config logic (e.g. an ExUnit `@tag timeout:`
set via a `tag/2` callback).

### 3. Audit your `Background:` blocks — they now RUN

Previously `Background` steps were broken and effectively **skipped**. In 1.0.0
they are prepended to every scenario in the feature (correct Cucumber behaviour,
implemented via pickle expansion). If a feature relied on Background being a
no-op, those steps will now execute — make sure they:

- have matching step definitions, and
- are safe to run before every scenario (idempotent setup).

### 4. Replace the non-standard `{name:type}` step sugar

Cabbage used to accept a cabbage-specific `{name:type}` step pattern (e.g.
`{count:int}`) that compiled to a regex with a *named* capture group and bound
the matched value into the step's `vars` map under that name. This was never
part of the Cucumber Expressions spec and has been **removed** in 1.0.0.

If you leave such a pattern in place, it now reaches the spec Cucumber
Expressions engine, which rejects `:` in a parameter-type name and raises at
compile time:

```
This Cucumber Expression has a problem at column 1:

{count:int} rows
^---------^
Undefined parameter type 'count:int'.
```

Find them:

```sh
grep -rnE '"\{[A-Za-z_][A-Za-z0-9_]*:[A-Za-z]+\}' test/ lib/
```

The faithful replacement is a **regex with a named capture**, which preserves
the named `vars` binding exactly:

```diff
- defgiven "{count:int} rows", %{count: count}, _state do
+ defgiven ~r/^(?<count>\d+) rows$/, %{count: count}, _state do
```

Type equivalents for the old `{name:type}` forms:

| old sugar       | named-capture regex            |
| --------------- | ------------------------------ |
| `{name:int}`    | `(?<name>\d+)`                 |
| `{name:float}`  | `(?<name>\d+\.\d+)`            |
| `{name:word}`   | `(?<name>\w*\S)`               |
| `{name:string}` | `(?<name>"(.*)")`              |

Alternatively, use a spec Cucumber Expression such as `{int}`, which now works
directly in `defgiven`/`defwhen`/`defthen`:

```diff
- defgiven "{count:int} rows", %{count: count}, _state do
+ defgiven "{int} rows", [count], _state do
```

Note the **tradeoff**: spec parameters are *positional*, not named. `{int}` binds
its value (already transformed to an integer) into the matched-data **list**
rather than a `%{count: count}` map, so you address it by position (`[count]`),
not by name. Use the regex form above if you specifically need the named variable
in a map.

## Step definitions are keyword-agnostic

A step matches a feature line by its **pattern only** — the
`Given`/`When`/`Then`/`And`/`But` keyword is not part of matching (this was already
true at runtime; it is now the documented contract). Your existing
`defgiven`/`defwhen`/`defthen` definitions keep working and are encouraged for
readability. New in 1.0.0:

- `defstep/3,4` — a canonical, keyword-neutral macro. Use it in shared step
  libraries where forcing a `defgiven` above a `Then`-matching step would be
  misleading.
- `defand/4` and `defbut/4` — aliases for `And`/`But` steps.

All six register identically; pick whichever reads best. No code change is
required.

## State contract

A step's return value drives the context threaded to the next step:

| Return value       | Effect on the context                                  |
| ------------------ | ------------------------------------------------------ |
| `:ok` or `nil`     | context unchanged                                      |
| `{:ok, map}`       | `Map.merge(context, map)` — delta-merge (recommended)  |
| a bare `map`       | **replaces** the context with that map                 |
| `{:error, reason}` | the step fails (raises, naming the step and reason)    |
| anything else      | the step fails (raises, naming the step and the value) |

The `{:ok, map}` merge that 0.4.1 steps already use is unchanged, and a bare-map
return now explicitly **replaces** the context (use it to reset state).

**What changed:** the old contract *silently kept* the context for any return it
did not recognise. A step that "updated state" but forgot the `{:ok, ...}` wrapper
would quietly no-op. That silent-keep is gone — a non-conforming return now raises.

Audit assertion-only steps and steps whose last expression is not a context value.
The fix is to return `:ok` explicitly:

```diff
  defthen ~r/^the total is (?<n>\d+)$/, %{n: n}, ctx do
    assert ctx.total == String.to_integer(n)
+   :ok
  end
```

A bare trailing `assert` returns a boolean, which is non-conforming and will raise;
end such steps with `:ok`. Note also that the context must be a **plain map** —
returning a struct (bare or `{:ok, struct}`) raises rather than replacing or
merging.

## Sharing steps

If you previously shared steps by copy-pasting them or by `import_feature`-ing a
file-less `use Cabbage.Feature` module, prefer a `Cabbage.Steps` module: a step
library that is *not* an ExUnit case and generates no tests.

```elixir
defmodule MyApp.SharedSteps do
  use Cabbage.Steps

  defstep "I am logged in as {string}", [user], _ctx do
    {:ok, %{user: user}}
  end
end
```

Import it with the `:import` option (it takes a list):

```elixir
defmodule MyApp.CheckoutTest do
  use Cabbage.Feature, file: "checkout.feature", import: [MyApp.SharedSteps]
end
```

Local steps win over imported ones on a same-pattern collision. The existing
`import_feature/1`, `import_steps/1`, and `import_tags/1` macros are unchanged and
still work — a file-less `use Cabbage.Feature` module remains a valid import
source — but `use Cabbage.Steps` is the recommended way to write a step library, as
it does not pull `ExUnit.Case` into a module that defines no tests. As before,
imported modules must compile first, so keep them under `test/support` (on
`elixirc_paths(:test)`).

## What you might change (only if you matched internals)

If any of your code pattern-matched on parser/AST structs, the internal struct
modules were renamed:

| 0.4.1 | 1.0.0 |
| --- | --- |
| `Gherkin.Elements.Document` (or similar) | `Cabbage.Feature.Document` |
| `Gherkin.Elements.Scenario` | `Cabbage.Feature.Scenario` |
| `Gherkin.Elements.Step` | `Cabbage.Feature.Step` |

Normal step definitions never reference these, so most projects skip this step.

## What you get for free

- **Scenario Outlines, `Rule:`, and `Background:`** all work via spec-compliant
  pickle expansion.
- **Cucumber Expressions** (`{int}`, `{string}`, `{word}`, custom params) in
  addition to the existing regex step matching.
- An optional **`on_ambiguous_step:`** mode if you want ambiguous matches to
  raise instead of silently picking the last-defined step.

## Verifying your upgrade

```sh
mix deps.get
mix compile --warnings-as-errors
mix test
```

If compilation fails, it is almost always (1) an Elixir/gherkin version mismatch
or (2) a valued tag in a `.feature` file — see sections above.
