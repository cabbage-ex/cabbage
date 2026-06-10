defmodule Cabbage.Messages.StepRegistry do
  @moduledoc """
  An ordered collection of step definitions for the message-emitting runner
  (`Cabbage.Messages`).

  This is intentionally separate from `Cabbage.Feature`'s compile-time, ExUnit-bound
  step machinery. The runner is a direct interpreter over `Gherkin.Pickle` steps, so
  it needs a plain, runtime-inspectable registry rather than module attributes baked
  into a test module.

  A step definition pairs a *pattern* (a Cucumber Expression string or an Elixir
  `Regex`) with a 0-arity-or-more function executed when a pickle step matches. The
  registry preserves registration order, which the runner uses to assign the stable,
  sequential ids the cucumber-messages goldens expect.

  ## Pattern kinds

    * a **binary** is a Cucumber Expression (`"I have {int} cukes"`), reported in the
      `stepDefinition` envelope as `CUCUMBER_EXPRESSION`;
    * a **`Regex`** is a regular expression, reported as `REGULAR_EXPRESSION`;
    * a binary whose Cucumber Expression references an *unregistered* `{type}` compiles
      to an `:undefined` definition — it never matches (so the step is reported
      `UNDEFINED`) and the offending type is recorded in `undefined_parameter_types`,
      which the runner emits as an `undefinedParameterType` message instead of a
      `stepDefinition`.

  Matching against a defined pattern yields the captured arguments *and* their
  source-text offsets, which the runner serializes into `stepMatchArgumentsLists`.

  ## Custom parameter types

  `define_parameter_type/2` registers a domain-specific `{type}` (name + regexp +
  transform) into the backing `Cabbage.CucumberExpression.ParameterTypeRegistry` so it
  can be used inside subsequent Cucumber Expressions, and records it (with its source
  reference) for the `parameterType` message. Built-in types (int/float/word/...) are
  *not* surfaced — only the custom ones the suite registered.
  """

  alias Cabbage.CucumberExpression
  alias Cabbage.CucumberExpression.ParameterType
  alias Cabbage.CucumberExpression.ParameterTypeRegistry
  alias Cabbage.Messages.StepRegistry.{ParameterTypeDefinition, StepDefinition, UndefinedParameterType}

  @type t :: %__MODULE__{
          definitions: [StepDefinition.t()],
          parameter_registry: ParameterTypeRegistry.t(),
          parameter_types: [ParameterTypeDefinition.t()],
          undefined_parameter_types: [UndefinedParameterType.t()]
        }

  defstruct definitions: [],
            parameter_registry: nil,
            parameter_types: [],
            undefined_parameter_types: []

  defmodule StepDefinition do
    @moduledoc "A single registered step definition: a pattern, a run function, and a source reference."

    @type pattern_kind :: :cucumber_expression | :regular_expression | :undefined

    @type t :: %__MODULE__{
            pattern_kind: pattern_kind(),
            source: String.t(),
            compiled: term(),
            fun: function(),
            uri: String.t() | nil,
            line: pos_integer() | nil
          }

    defstruct [:pattern_kind, :source, :compiled, :fun, :uri, :line]
  end

  defmodule ParameterTypeDefinition do
    @moduledoc """
    A custom parameter type registered on a `StepRegistry`: the engine
    `ParameterType` plus the source reference (`uri`/`line`) the `parameterType`
    message carries. Built-in types are never wrapped in this struct.
    """

    @type t :: %__MODULE__{
            name: String.t(),
            regexps: [String.t()],
            use_for_snippets: boolean(),
            prefer_for_regexp_match: boolean(),
            uri: String.t() | nil,
            line: pos_integer() | nil
          }

    defstruct [:name, :regexps, :use_for_snippets, :prefer_for_regexp_match, :uri, :line]
  end

  defmodule UndefinedParameterType do
    @moduledoc """
    A record that a step definition referenced an unregistered `{type}`. The runner
    emits one `undefinedParameterType` message per record (name + the full expression).
    """

    @type t :: %__MODULE__{name: String.t(), expression: String.t()}

    defstruct [:name, :expression]
  end

  @doc "An empty registry backed by the default parameter-type registry (int/float/word/string)."
  @spec new() :: t()
  def new do
    %__MODULE__{parameter_registry: ParameterTypeRegistry.new()}
  end

  @doc """
  Register a custom parameter type so it can be used inside Cucumber Expressions.

  Options:

    * `:name` (required) — the `{name}` referenced in expressions;
    * `:regexp` / `:regexps` (required) — a `Regex`, a source string, or a list of
      either; capture groups in the regexp become the parameter's match-argument
      children;
    * `:transform` — a 1-arity function receiving the list of captured strings and
      returning the value passed to the step function (defaults to the first capture);
    * `:use_for_snippets` (default `true`), `:prefer_for_regexp_match` (default `false`)
      — surfaced verbatim in the `parameterType` message;
    * `:uri` / `:line` — the type's `sourceReference` in the message.

  Raises `Cabbage.CucumberExpression.Errors.CucumberExpressionError` if `name` is
  already registered.
  """
  @spec define_parameter_type(t(), keyword()) :: t()
  def define_parameter_type(%__MODULE__{} = registry, opts) do
    regexps = Keyword.get(opts, :regexps) || Keyword.fetch!(opts, :regexp)

    type =
      ParameterType.new(
        name: Keyword.fetch!(opts, :name),
        regexps: regexps,
        transform: Keyword.get(opts, :transform, fn values -> List.first(values) end),
        use_for_snippets: Keyword.get(opts, :use_for_snippets, true),
        prefer_for_regexp_match: Keyword.get(opts, :prefer_for_regexp_match, false)
      )

    parameter_registry = ParameterTypeRegistry.define(registry.parameter_registry, type)

    definition = %ParameterTypeDefinition{
      name: type.name,
      regexps: type.regexps,
      use_for_snippets: type.use_for_snippets,
      prefer_for_regexp_match: type.prefer_for_regexp_match,
      uri: opts[:uri],
      line: opts[:line]
    }

    %{
      registry
      | parameter_registry: parameter_registry,
        parameter_types: registry.parameter_types ++ [definition]
    }
  end

  @doc """
  Register a step definition.

  `pattern` is a Cucumber Expression string or a `Regex`. `fun` receives the matched,
  transformed arguments (one per capture) and may return `:ok`/`nil`/`{:ok, world}`
  (PASSED), the strings `"pending"`/`"skipped"`, raise `Cabbage.PendingError` /
  `Cabbage.SkippedError` (PENDING/SKIPPED *with* an exception), or raise anything else
  (FAILED) — see `Cabbage.Messages` for the full status mapping. `:uri`/`:line` populate
  the emitted `stepDefinition.sourceReference`.

  A Cucumber Expression that references an unregistered `{type}` does not raise: the
  definition is recorded as `:undefined` (it never matches, so the step is reported
  `UNDEFINED`) and the offending type is added to `undefined_parameter_types/1`.
  """
  @spec add(t(), String.t() | Regex.t(), function(), keyword()) :: t()
  def add(%__MODULE__{} = registry, pattern, fun, opts \\ []) when is_function(fun) do
    {definition, registry} = build_definition(registry, pattern, fun, opts)
    %{registry | definitions: registry.definitions ++ [definition]}
  end

  defp build_definition(registry, pattern, fun, opts) when is_binary(pattern) do
    # Messages-layer policy: every *binary* is a Cucumber Expression (reported
    # CUCUMBER_EXPRESSION), even a parameter-free one like "an action" — unlike the
    # Feature layer, which treats a braceless binary as a literal regex. So the
    # binary-vs-regex dispatch stays here. What is shared with the Feature layer is the
    # expression *compilation*, routed through `Cabbage.StepPattern.classify_expression/2`
    # (which compiles the source against this registry's parameter types and tags it).
    #
    # Detect a reference to an unregistered `{type}` *before* classifying (which would
    # raise on compile). Such a step is "effectively undefined": record the offending
    # type for the `undefinedParameterType` message and mark the def so it never matches.
    case first_undefined_parameter_type(registry, pattern) do
      nil ->
        {:cucumber_expression, compiled} = Cabbage.StepPattern.classify_expression(pattern, registry.parameter_registry)

        definition = %StepDefinition{
          pattern_kind: :cucumber_expression,
          source: pattern,
          compiled: compiled,
          fun: fun,
          uri: opts[:uri],
          line: opts[:line]
        }

        {definition, registry}

      name ->
        definition = %StepDefinition{
          pattern_kind: :undefined,
          source: pattern,
          compiled: nil,
          fun: fun,
          uri: opts[:uri],
          line: opts[:line]
        }

        undefined = %UndefinedParameterType{name: name, expression: pattern}

        registry = %{
          registry
          | undefined_parameter_types: registry.undefined_parameter_types ++ [undefined]
        }

        {definition, registry}
    end
  end

  defp build_definition(registry, %Regex{} = pattern, fun, opts) do
    {:regex, regex} = Cabbage.StepPattern.classify_expression(pattern, registry.parameter_registry)

    definition = %StepDefinition{
      pattern_kind: :regular_expression,
      source: Regex.source(regex),
      compiled: regex,
      fun: fun,
      uri: opts[:uri],
      line: opts[:line]
    }

    {definition, registry}
  end

  # The first `{type}` in `pattern` not present in the parameter registry, or `nil` when
  # every referenced type is registered. (Malformed expressions still raise on compile.)
  defp first_undefined_parameter_type(registry, pattern) do
    pattern
    |> CucumberExpression.parameter_type_names()
    |> Enum.find(fn name ->
      ParameterTypeRegistry.lookup_by_type_name(registry.parameter_registry, name) == nil
    end)
  end

  @doc "The registered definitions, in registration order."
  @spec definitions(t()) :: [StepDefinition.t()]
  def definitions(%__MODULE__{definitions: definitions}), do: definitions

  @doc "The custom parameter types registered on this registry, in registration order."
  @spec parameter_types(t()) :: [ParameterTypeDefinition.t()]
  def parameter_types(%__MODULE__{parameter_types: parameter_types}), do: parameter_types

  @doc "The undefined-parameter-type records collected while registering step definitions."
  @spec undefined_parameter_types(t()) :: [UndefinedParameterType.t()]
  def undefined_parameter_types(%__MODULE__{undefined_parameter_types: types}), do: types
end
