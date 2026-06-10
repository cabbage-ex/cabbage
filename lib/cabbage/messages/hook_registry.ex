defmodule Cabbage.Messages.HookRegistry do
  @moduledoc """
  An ordered collection of *hooks* for the message-emitting runner (`Cabbage.Messages`).

  A hook is a function run around a scenario or around the whole test run, rather than in
  response to a matching pickle step. Like `Cabbage.Messages.StepRegistry`, this is a plain,
  runtime-inspectable registry (not the compile-time `Cabbage.Feature` machinery), so the
  interpreter can assign stable ids and emit the `hook` / `testRunHook*` envelopes the
  cucumber-messages goldens expect.

  ## Hook kinds

  Each hook has a `type`, mirroring the cucumber-messages `HookType` enum:

    * `:before_test_case` / `:after_test_case` — run before/after a scenario's steps
      (`BEFORE_TEST_CASE` / `AFTER_TEST_CASE`). Optionally scoped to scenarios whose tags
      satisfy a `Cabbage.TagExpression` (`tag_expression`).
    * `:before_test_run` / `:after_test_run` — run once before/after the whole run
      (`BEFORE_TEST_RUN` / `AFTER_TEST_RUN`, a.k.a. `BeforeAll`/`AfterAll`). Tag expressions
      do not apply.

  A hook may carry an optional `name` (reported verbatim in the `hook` envelope).

  ## Registration order

  Registration order is preserved and is meaningful: `BeforeAll` hooks run in registration
  order, `AfterAll` hooks run in *reverse* registration order, and scenario before/after
  hooks run in registration order (the reference `fake-cucumber` semantics).

  ## Outcome protocol

  A hook's run function follows the same protocol as a step definition (see
  `Cabbage.Messages`): `:ok`/`nil`/`{:ok, world}` -> PASSED, `"skipped"` -> SKIPPED,
  raising `Cabbage.SkippedError` -> SKIPPED with an exception, any other raise -> FAILED.
  """

  alias Cabbage.Messages.HookRegistry.Hook

  @type t :: %__MODULE__{hooks: [Hook.t()]}

  defstruct hooks: []

  defmodule Hook do
    @moduledoc "A single registered hook: a type, a run function, and an optional name/tag expression."

    @type hook_type ::
            :before_test_case | :after_test_case | :before_test_run | :after_test_run

    @type t :: %__MODULE__{
            type: hook_type(),
            fun: function(),
            name: String.t() | nil,
            tag_expression: String.t() | nil,
            uri: String.t() | nil,
            line: pos_integer() | nil
          }

    defstruct [:type, :fun, :name, :tag_expression, :uri, :line]
  end

  @scenario_types [:before_test_case, :after_test_case]
  @global_types [:before_test_run, :after_test_run]

  @doc "An empty hook registry."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Register a hook of `type` with run function `fun`.

  Options:

    * `:name` — a human-readable name reported in the `hook` envelope;
    * `:tag` — a `Cabbage.TagExpression` string scoping a scenario hook to matching pickles
      (ignored for global hooks);
    * `:uri` / `:line` — populate the emitted `hook.sourceReference`.
  """
  @spec add(t(), Hook.hook_type(), function(), keyword()) :: t()
  def add(%__MODULE__{} = registry, type, fun, opts \\ [])
      when type in @scenario_types or type in @global_types do
    hook = %Hook{
      type: type,
      fun: fun,
      name: opts[:name],
      tag_expression: opts[:tag],
      uri: opts[:uri],
      line: opts[:line]
    }

    %{registry | hooks: registry.hooks ++ [hook]}
  end

  @doc "All registered hooks, in registration order."
  @spec hooks(t()) :: [Hook.t()]
  def hooks(%__MODULE__{hooks: hooks}), do: hooks

  @doc "Scenario (before/after) hooks, in registration order."
  @spec scenario_hooks(t()) :: [Hook.t()]
  def scenario_hooks(%__MODULE__{hooks: hooks}),
    do: Enum.filter(hooks, &(&1.type in @scenario_types))

  @doc "Global (BeforeAll/AfterAll) hooks, in registration order."
  @spec global_hooks(t()) :: [Hook.t()]
  def global_hooks(%__MODULE__{hooks: hooks}),
    do: Enum.filter(hooks, &(&1.type in @global_types))
end
