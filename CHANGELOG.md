# Changelog

## 1.0.0

Cabbage graduates to `1.0.0`. The internals are a ground-up rewrite onto a
spec-conformant Gherkin pipeline and a cucumber-messages runner, and the step
API is overhauled: keyword-agnostic step macros, shared `Cabbage.Steps`
libraries, string Cucumber Expressions, and an explicit step state contract.
Most existing 0.4.1 step modules still compile and run; the one behavioural
change to audit is the state contract (see Breaking). See
[UPGRADING.md](UPGRADING.md).

### Breaking

- **Elixir floor raised** from `~> 1.13` to `~> 1.18`. Cabbage now relies on
  the built-in `JSON` module (Elixir 1.18+) and drops the `jason`/`excoveralls`
  dependencies entirely.
- **Requires gherkin `~> 3.0`.** The runner consumes the rewritten gherkin
  pipeline (`Gherkin.parse!/2` + `Gherkin.pickles/2`); gherkin `2.x` will not
  work.
- **Non-standard "valued" tags are rejected.** Tags like `@timeout 100` are not
  valid Gherkin and now raise a parse error. Use a plain tag (`@timeout`) plus
  step/config logic, or split the value into its own construct.
- **Background steps now EXECUTE.** Previously `Background` steps were silently
  broken and effectively skipped; they are now prepended to every scenario in
  the feature (via pickle expansion), matching Cucumber semantics. Features that
  relied on Background being a no-op may now run those steps.
- **Removed the non-standard `{name:type}` named-capture step sugar.** Patterns
  like `defgiven "{count:int} rows", ...` were a cabbage-specific extension that
  compiled to a named-capture regex (`(?<count>\d+)`) and bound `count` into the
  step's `vars`. It is **not** part of the Cucumber Expressions spec and has been
  dropped. Such a pattern now flows to the spec engine and raises an
  `Undefined parameter type 'count:int'` compile error. Replace it with a regex
  carrying a named capture — `~r/(?<count>\d+) rows/` — to keep the named `vars`
  binding. (Spec expressions like `{int}` match, but bind positionally, not by
  name.) See `UPGRADING.md`.
- **Internal struct modules renamed:** `Gherkin.Elements.*` →
  `Cabbage.Feature.{Document, Scenario, Step}`. This only affects code that
  pattern-matched on Cabbage/Gherkin internals; step-definition code is
  unaffected.
- **Removed the internal state helpers** `Cabbage.Feature.Helpers.start_state/3`,
  `fetch_state/2`, `update_state/3`, and `agent_name/2` (the module is
  `@moduledoc false`). Step code never called these; only code reaching into
  cabbage internals or relying on the per-scenario Agent process is affected.
- **Explicit step state contract; silent-keep removed.** A step's return value
  now drives the context by an explicit rule: `:ok`/`nil` keep it, `{:ok, map}`
  merges (delta-merge, the everyday form), a bare `map` **replaces** it, and
  `{:error, reason}` or any non-conforming value **raises** (naming the step). The
  `{:ok, map}` merge that every 0.4.1 step uses is unchanged, so most modules need
  no edits. The behavioural change to audit: a step that previously returned a
  stray non-conforming value and relied on the old contract *silently keeping*
  state now raises — add an explicit `:ok` to such steps. Returning a struct (bare
  or `{:ok, struct}`) also raises: the context must be a plain map. The reserved
  context keys `:__table__`/`:__doc_string__` are stripped from threaded state.

### Changed

- **Scenario state is now threaded as a value, not held in an `Agent`.** The
  `Feature` runner compiles each step to a `fn context -> next_context end` and
  threads the scenario's context through them with a reduce. Previously state lived
  in a per-scenario `Agent` registered under a global name.
  - **`async: true` is now safe by construction.** The old global Agent name
    (`cabbage_integration_test-<scenario>-<module>`) could collide and leak state
    between same-named scenarios / re-runs; threaded state is per-invocation.
  - **No more leaked processes.** The Agent was started and never stopped.

### Source-compatible

- Existing step definitions compile as-is — `use Cabbage.Feature, file: ...,
  template: ...`, `defgiven`/`defwhen`/`defthen`, `import_feature/1`,
  `import_steps/1`, `import_tags/1`, and `tag/2` are all retained — provided steps
  return a contract-conforming value (`:ok`/`nil`/`{:ok, map}`/a map). See the state
  contract under Breaking.

### Added

- **Keyword-agnostic step macros.** `defstep/3,4` is the canonical, keyword-neutral
  step macro; matching is by **pattern only** (the `Given`/`When`/`Then` keyword
  never gates a match). `defgiven`/`defwhen`/`defthen` are kept and `defand`/`defbut`
  are added, all as readability aliases that register identically.
- **`Cabbage.Steps` — shared step libraries.** `use Cabbage.Steps` builds a module
  of reusable step definitions that is *not* an ExUnit case and generates no tests.
  Import it into a feature with `use Cabbage.Feature, ..., import: [Mod, ...]`. Local
  steps win first-match on a same-pattern collision; imported steps follow in a
  deterministic order; importing a non-step module raises a clear error; step
  libraries compose transitively.
- **Reserved context keys for tables/doc strings.** A step's gherkin data table and
  doc string are reachable from the context as `ctx.__table__` and
  `ctx.__doc_string__` (empty list / empty string when absent), injected per step and
  not threaded forward — the uniform path for Cucumber Expression steps.

- **Pickle-based execution.** Background prepending, `Rule` flattening, and
  Scenario Outline expansion now come "for free" from the gherkin pickle
  compiler instead of bespoke Cabbage logic.
- **Full Cucumber Expressions engine** (`{int}`, `{word}`, `{string}`,
  custom/optional/alternation), validated at **115/115** against the upstream
  cucumber-expressions conformance corpus.
- **String Cucumber Expression patterns in `Cabbage.Feature` step macros.**
  `defgiven`/`defwhen`/`defthen` now accept a string Cucumber Expression
  (`defgiven "I have {int} cucumbers", [count], state`) alongside `~r/regex/`.
  The expression is matched through the engine above, so arguments arrive as a
  positional list of *transformed* values (`{int}` -> integer, `{float}` ->
  float, `{string}`/`{word}` -> string). Regex patterns are unchanged and still
  bind a named-captures map. (Built-in parameter types only; there is no
  public custom-parameter-type API for `Cabbage.Feature`.)
- **Tag Expressions engine** (`and`/`or`/`not`/parentheses), validated at
  **64/64** against the upstream tag-expressions corpus.
- **Shared pattern core (`Cabbage.StepPattern`).** Pattern classification (regex
  vs Cucumber Expression vs literal) and match extraction are factored into one
  internal module used by both the `Cabbage.Feature` compile-time runner and the
  `Cabbage.Messages` runtime runner, removing duplicated matching logic. (The two
  execution paths remain separate; full convergence is a future release.)
- **cucumber-messages runner** (`Cabbage.Messages`) with hooks, attachments,
  retry, and parameter-types support — validated at **43/44** against the
  Cucumber Compatibility Kit (CCK) (the 44th asserts a run-level crash and is
  deferred as `unsupported`).
- **Opt-in ambiguous-step handling** via `on_ambiguous_step:` in
  `@feature_options` (default preserves prior last-match-wins behaviour).
- **`Cabbage.Formatter` — an ExUnit formatter that emits a cucumber-messages
  NDJSON stream from a normal `mix test` run.** Enable it alongside the default
  CLI formatter:

      ExUnit.start(formatters: [ExUnit.CLIFormatter, Cabbage.Formatter])

  For every `Cabbage.Feature` scenario it writes `meta`, per-feature
  `source`/`gherkinDocument`/`pickle`, `testRunStarted`, and per-scenario
  `testCase`/`testCaseStarted`/`testStepStarted`/`testStepFinished`/`testCaseFinished`,
  closing with `testRunFinished` whose `success` flag reflects the run. Output
  defaults to `cucumber-messages.ndjson` and is configurable via
  `config :cabbage, messages_output: "path.ndjson"` or the formatter's
  `:messages_output` option. The parser-side envelopes reuse the gherkin
  dependency's `Gherkin.Message` builders.
  - **Step results are scenario-level.** Because cabbage runs every step inside one
    generated ExUnit test, each step is attributed the scenario's outcome uniformly
    (all `PASSED`, all `FAILED`, or all `SKIPPED`); the run-level `success` flag is
    exact. Granular per-step attribution is a planned follow-up.

See [UPGRADING.md](UPGRADING.md) for a 0.4.1 → 1.0.0 migration guide.

### v0.4.1

- Updated dependencies, remove dependency on retired `gherkin 1.6.1`

### v0.4.0

- Support for new Elixir versions >= 1.13

### v0.3.4-dev

- Support for Elixir 1.7 #50.

### v0.3.3

- Support for Elixir 1.5 #38. Thanks to @lboekhorst and @rawkode

### v0.3.2

- Fix for improper state tracking #33. Thanks to @lboekhorst

### v0.3.1

- Better support for missing steps (produces the pattern match for the given missing data). #26 Thanks to @shdblowers
- Breaks `import_feature/1` into two separate macros for more explicit control. Issue #21. Thanks for @hisapy for the
  suggestion.

### v0.3.0

- Support for running specific tests #15 on a specific line number.
- Bug fix #19 Thanks to @rawkode - Defaulting steps and tags to empty list when get_attributes returns nil
- Missing step advisor improvements #14 Thanks to @shdblowers
- Data tables and doc strings are now available in the variables under the `:table` and `:doc_string` keys

### v0.2.2

- Support for ExUnit case templates. Simply specify the case template module name like
  `use Cabbage, template: MyApp.ConnCase, feature: "some_file.feature"`
- Support for tags as ExUnit setup callbacks.

### v0.2.1

- Bug fix #9 Thanks to @shdblowers - Fixes updating of state properly from one step to the next

### v0.2.0

- Support for Scenario Outlines. Scenario Outlines are supported by expanding them into
  basic scenarios by filling in all variables. The name of each scenario is appended to have
  `(Example x)` where `x` is the row from the `Examples` block in the Scenario Outline. See
  https://github.com/cabbage-ex/cabbage/blob/master/test/outline_test.exs for an example.

### v0.1.0

- Initial features to run a simple scenario with variable matching and state tracking.
