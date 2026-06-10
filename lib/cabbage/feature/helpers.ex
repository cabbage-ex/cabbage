defmodule Cabbage.Feature.Helpers do
  @moduledoc false
  require Logger

  def add_step(module, string_or_regex, vars, state, block, metadata) do
    pattern = to_pattern_ast(string_or_regex)

    Module.put_attribute(module, :steps, {:{}, [], [pattern, vars, state, block, metadata]})
    quote(do: nil)
  end

  # Step-pattern classification (the binary-with-`{...}` vs literal vs `~r//`
  # decision, with the same `{name:type}` validation UX) lives in the shared
  # `Cabbage.StepPattern.classify/2`. Here we only turn the classified result into
  # the stored AST shape the Feature runner expects:
  #
  #   * `~r/.../` regex (and the escaped-anchored regex for a literal binary) is
  #     stored as a `Regex` literal AST, matched with `Regex.named_captures` so its
  #     matched data is a *map* of named captures (string values);
  #
  #   * a Cucumber Expression is stored as a `{:cucumber_expression, source}` marker
  #     (the source string, NOT the compiled struct — `eval_pattern/1` recompiles it
  #     at the feature module's compile time) and matched through the real engine,
  #     `Cabbage.CucumberExpression`, so its matched data is a positional *list* of
  #     transformed argument values (`{int}` -> integer, etc.).
  #
  # Classifying here also validates the expression at the definition site: the
  # removed `{name:type}` sugar (e.g. `{count:int}`) raises a clear
  # `Undefined parameter type` compile error at the `defgiven`/`defstep` line.
  defp to_pattern_ast(term) when is_binary(term) do
    case Cabbage.StepPattern.classify(term, Cabbage.StepPattern.standard_registry()) do
      {:cucumber_expression, _compiled} -> Macro.escape({:cucumber_expression, term})
      {:regex, regex} -> Macro.escape(regex)
    end
  end

  defp to_pattern_ast(term), do: term

  def add_tag(module, "@" <> tag_name, block), do: add_tag(module, tag_name, block)

  def add_tag(module, tag_name, block) do
    Module.put_attribute(module, :tags, {tag_name, block})
    quote(do: nil)
  end

  def evaluate_tag_block(block) do
    {new_state, _} = Code.eval_quoted(block)

    case new_state do
      {:ok, state} -> state
      _ -> %{}
    end
  end

  def file(file) do
    String.replace_leading(file, "#{File.cwd!()}/", "")
  end

  def metadata(env, function) do
    %{file: file(env.file), line: env.line, module: env.module, function: function, arity: 4}
  end

  def stacktrace(module, metadata) do
    [
      {module, metadata[:function], metadata[:arity], [file: metadata[:file], line: metadata[:line]]}
    ]
  end

  # Applies a step block's return value to the threaded context (the state contract):
  #
  #   :ok | nil          -> context unchanged
  #   {:ok, map}         -> Map.merge(context, map)        (delta-merge; back-compat)
  #   a plain map        -> replaces the context with that map
  #   {:error, reason}   -> raise (the step reported failure)
  #   a struct / other   -> raise (a non-conforming return; no silent keep)
  #
  # Clause order matters: `{:error, _}` is a tuple, and a struct satisfies `is_map/1`,
  # so the struct clauses (bare and `{:ok, _}`-wrapped) are matched before their
  # plain-map counterparts. Failures raise with the step's own metadata for a useful
  # stacktrace.
  def apply_step_return(:ok, state, _step_text, _module, _metadata), do: state
  def apply_step_return(nil, state, _step_text, _module, _metadata), do: state

  # `{:ok, struct}` must not merge: it would inject :__struct__ + the struct's fields
  # into the context, bypassing exactly what the bare-struct clause below forbids.
  def apply_step_return({:ok, %_{} = struct}, _state, step_text, module, metadata) do
    reraise "Step #{inspect(step_text)} returned {:ok, #{inspect(struct.__struct__)} struct}; " <>
              "the context must be a plain map. Return a plain map, {:ok, map}, or :ok.",
            stacktrace(module, metadata)
  end

  def apply_step_return({:ok, map}, state, _step_text, _module, _metadata) when is_map(map) do
    Map.merge(state, map)
  end

  def apply_step_return({:error, reason}, _state, step_text, module, metadata) do
    reraise "Step #{inspect(step_text)} returned {:error, #{inspect(reason)}}; the step reported failure.",
            stacktrace(module, metadata)
  end

  def apply_step_return(%_{} = struct, _state, step_text, module, metadata) do
    reraise "Step #{inspect(step_text)} returned a struct (#{inspect(struct.__struct__)}); " <>
              "the context must be a plain map. Return a plain map, {:ok, map}, or :ok.",
            stacktrace(module, metadata)
  end

  # A bare (non-struct) map REPLACES the context.
  def apply_step_return(map, _state, _step_text, _module, _metadata) when is_map(map), do: map

  def apply_step_return(other, _state, step_text, module, metadata) do
    reraise "Step #{inspect(step_text)} returned #{inspect(other)}; " <>
              "expected :ok | nil | a map | {:ok, map}.",
            stacktrace(module, metadata)
  end

  @keys ~w(async case describe file integration line test type scenario case_template registered __table__ __doc_string__)a
  def remove_hidden_state(state) do
    Map.drop(state, @keys)
  end

  @doc false
  # Normalizes the ExUnit `setup` context into a scenario's starting state map, dropping the
  # ExUnit/cabbage bookkeeping keys that should never be visible to a step's state pattern.
  def init_context(exunit_state) do
    exunit_state |> to_map() |> remove_hidden_state()
  end

  @doc false
  # Folds a scenario's tags through the module's registered `tag` blocks and returns the merged
  # state map they contribute. Pure (no process) — replaces the Agent-seeding `run_tag/4`; the
  # result is merged into the scenario's initial context by the generated `setup` block.
  def collect_tag_state(tags, scenario_tags) do
    for tag <- scenario_tags, reduce: %{} do
      acc -> Map.merge(acc, tag_state(tags, tag))
    end
  end

  # Cabbage `tag` blocks are keyed by an atom/binary name. ExUnit-style valued tags
  # (e.g. `@moduletag timeout: 100`, which reaches here as `{:timeout, 100}`) are not cabbage
  # tag blocks — they configure ExUnit, not cabbage state — so they contribute no state.
  defp tag_state(tags, {tag, _value}), do: tag_state(tags, tag)

  defp tag_state(tags, tag) when is_atom(tag) or is_binary(tag) do
    string_tag = to_string(tag)

    case Enum.find(tags, &match?({^string_tag, _}, &1)) do
      {^string_tag, block} ->
        Logger.debug("Cabbage: Running tag @#{tag}...")
        evaluate_tag_block(block)

      _ ->
        %{}
    end
  end

  defp tag_state(_tags, _tag), do: %{}

  def map_tags(tags) do
    tags
    |> Enum.map(fn
      {tag, value} ->
        [{tag, value}]

      tag ->
        tag
    end)
  end

  @doc false
  # Normalizes the ExUnit `setup` context into a plain map. Older Elixir versions
  # passed `nil` when no context was present; newer ones pass a keyword list.
  def to_map(value) when is_map(value), do: value
  def to_map(value) when is_list(value), do: Map.new(value)
  def to_map(nil), do: %{}

  @doc false
  # Version-conditional wrapper around `ExUnit.Case.register_test`. Elixir 1.16+
  # exposes the 6-arity form (`module, file, line, type, name, tags`) and
  # deprecated the 4-arity `(env, type, name, tags)` form. We call whichever is
  # available so cabbage compiles warning-free across Elixir 1.15 - 1.19.
  def register_test(env, test_type, name, tags) do
    if function_exported?(ExUnit.Case, :register_test, 6) do
      apply(ExUnit.Case, :register_test, [env.module, env.file, env.line, test_type, name, tags])
    else
      apply(ExUnit.Case, :register_test, [env, test_type, name, tags])
    end
  end
end
