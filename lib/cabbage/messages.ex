defmodule Cabbage.Messages do
  @moduledoc """
  A direct, message-emitting Cucumber runner: parse a feature to pickles, execute each
  pickle's steps against a step registry, and emit the full cucumber-messages
  `Envelope` stream (the same stream a future `message` formatter would produce).

  This is deliberately a *separate execution path* from `Cabbage.Feature`. `Cabbage.Feature`
  generates ExUnit tests at compile time and is coupled to ExUnit's lifecycle, regex-only
  matching, and "raise on missing step" semantics. A conformance runner instead needs to
  observe every status (`passed | failed | undefined | pending | ambiguous | skipped`) and
  serialize a precise, ordered envelope stream — so it interprets pickle steps directly.

  ## Pipeline

      feature source --(Gherkin.parse/pickles)--> envelopes
                       Source, GherkinDocument, Pickle      (reused from the gherkin dep)
                     + StepDefinition*                      (one per registered step def)
                     + TestRunStarted
                     + TestCase*                            (one per pickle, all emitted first)
                     + per pickle: TestCaseStarted,
                         (TestStepStarted, [Suggestion], TestStepFinished)*,
                         TestCaseFinished
                     + TestRunFinished

  The envelope *order* mirrors fake-cucumber / cucumber-js: every `testCase` is emitted
  before any `testCaseStarted`. `run/3` accepts one feature; `run_features/2` aggregates
  several features into a single run (the `multiple-features` CCK shape).

  ## Code map

  The implementation reads top-to-bottom as the pipeline above. `run/3` and `run_features/3`
  are the entry points; `do_run_features/6` is the 7-step manifest that assembles the run.
  The phases it delegates to, in order:

    * `parser_envelopes/2` — Source/GherkinDocument/Pickle (per feature)
    * `registration_envelopes/3` — parameterType / hook / stepDefinition envelopes
    * `plan_and_execute/9` — plan each pickle into a TestCase, then run it
    * `execute_test_case/4` → `run_attempts/6` → `run_attempt/5` — the retry loop
    * `execute_steps/3` → `execute_step/3` — one step at a time
    * `intrinsic_status/3` then `report_status/2` — the status + skip-propagation machine

  ## Step outcome protocol

  A step definition's run function may return `:ok`, `nil`, `{:ok, world}`, the strings
  `"pending"`/`"skipped"`, or raise. The runner maps these to step statuses:

    * `:ok` / `nil` / `{:ok, world}` -> `PASSED`
    * `"pending"` / `"skipped"`       -> `PENDING` / `SKIPPED` (no `exception`)
    * `raise Cabbage.PendingError`    -> `PENDING` with `exception.type = "PendingException"`
    * `raise Cabbage.SkippedError`    -> `SKIPPED` with `exception.type = "SkippedException"`
    * any other raise                 -> `FAILED` (`AssertionError` for a failed match /
      ExUnit assertion, otherwise `Error`)

  Match count decides the rest: 0 matches -> `UNDEFINED` (+ a `suggestion` envelope),
  >1 -> `AMBIGUOUS`.

  ## Skip propagation (cucumber-js / CCK `failedish-combinations` semantics)

  A step's *intrinsic* status is computed first, then two flags thread through the
  scenario:

    * a prior step reported a non-`PASSED` status -> later *executable* steps (single
      match, would run a def) become `SKIPPED`, but `UNDEFINED`/`AMBIGUOUS` steps keep
      their intrinsic status;
    * a prior step's intrinsic status was `SKIPPED` (a `"skipped"` return or a raised
      `Cabbage.SkippedError`) -> *every* later step becomes `SKIPPED`, including
      `UNDEFINED`/`AMBIGUOUS` ones.

  The run is `success: true` iff every step is `PASSED` or `SKIPPED` (a scenario that only
  skips is still a successful run).

  ## Status / extension notes

  Run-structure envelopes are assembled here; Source/GherkinDocument/Pickle and NDJSON
  serialization are reused from `Gherkin.Message`. Hooks, attachments, parameter-type, and
  retry (`:retry`/`:retry_tag_expression`) envelopes are all emitted.

  ## Retry

  With `:retry N`, a test case whose attempt FAILS is re-run up to `N` additional times
  (cucumber-js retry semantics, CCK `retry*` areas). Each attempt emits its own
  `testCaseStarted` (same `testCaseId`, incrementing 0-based `attempt`) and a
  `testCaseFinished` whose `willBeRetried` is `true` on every non-final failed attempt.
  Only a FAILED outcome retries — `AMBIGUOUS`/`PENDING`/`UNDEFINED` will not pass however
  many times they are attempted, so they run exactly once. `:retry_tag_expression` (a
  `Cabbage.TagExpression` AST) limits retry to test cases whose pickle tags match.

  ## Attachments

  A step or hook body attaches data by calling `Cabbage.Messages.Attach.attach/3` (or
  `log/2` / `link/2`) with its `world`. The runner threads a per-run collector through the
  world under the reserved `:__attach__` key, drains it after each step/hook, and emits an
  `attachment` envelope per attachment *between* that step's `testStepStarted` and
  `testStepFinished` (or a global hook's `testRunHookStarted`/`testRunHookFinished`). The
  drain happens even when the body raised, so a body may attach *then* fail.

  Ambiguity is detected here via the match count. It is **not**
  surfaced in the compile-time `Cabbage.Feature` runner: that path's
  `find_implementation_of_step/2` uses first-match-wins, and existing feature modules may
  rely on that (general pattern + specific override). Turning first-match into a
  compile-time ambiguity error is a behavioural change for shipped code and is left to a
  dedicated change rather than this result-semantics wave.
  """

  alias Cabbage.Messages.{Attach, HookRegistry, Ids, Matcher, StepRegistry}
  alias Gherkin.Message

  import Cabbage.Messages.MapHelpers, only: [put_unless_nil: 3]

  @type envelope :: map()

  @doc """
  Run a single `feature_source` against `registry`, returning the ordered envelope list.

  Options:

    * `:uri` — the source uri embedded in Source/GherkinDocument/Pickle (default `""`);
    * `:format` — `:plain` (default) or `:markdown` for the Source media type;
    * `:hooks` — a `Cabbage.Messages.HookRegistry` of before/after-scenario and
      BeforeAll/AfterAll hooks (default: no hooks);
    * `:retry` — the maximum number of *additional* attempts a FAILED test case may be
      re-run (default `0`, i.e. no retry; `--retry N` in the CCK arguments);
    * `:retry_tag_expression` — an optional `Cabbage.TagExpression` AST; when set, only
      test cases whose pickle tags match it are eligible for retry (default: all cases).
  """
  @spec run(String.t(), StepRegistry.t(), keyword()) :: [envelope()]
  def run(feature_source, %StepRegistry{} = registry, opts \\ []) do
    {run_opts, feature_opts} = Keyword.split(opts, [:hooks, :retry, :retry_tag_expression])
    validate_feature_opts!(feature_opts)
    run_features([{feature_source, feature_opts}], registry, run_opts)
  end

  # The per-feature opts `run/3` understands. `:order` is deliberately NOT here: it is a
  # whole-run concern (it reverses planning/execution across every feature) and is read only
  # by `run_features/2`, never per feature. Passing it (or any other unknown key) to `run/3`
  # would silently do nothing, so we fail fast instead.
  @feature_opt_keys [:uri, :format]

  defp validate_feature_opts!(opts) do
    case Keyword.keys(opts) -- @feature_opt_keys do
      [] ->
        :ok

      unknown ->
        raise ArgumentError,
              "unknown option(s) #{inspect(unknown)} passed to Cabbage.Messages.run/3; " <>
                "valid per-feature options are #{inspect(@feature_opt_keys)}. " <>
                "(:order is a run-wide option read only by run_features/2.)"
    end
  end

  @doc """
  Run several features as one test run.

  `features` is a list of `{feature_source, opts}` (same per-feature opts as `run/3`,
  i.e. `:uri`/`:format`). `run_opts` may carry `:order` (`:reverse`), `:hooks` (a
  `Cabbage.Messages.HookRegistry`), `:retry` (max additional attempts for a FAILED case),
  and `:retry_tag_expression` (a `Cabbage.TagExpression` AST limiting which cases retry).
  The parser-side envelopes are emitted per feature
  (Source, GherkinDocument, Pickles), then a single set of Hook / StepDefinition / TestRun*
  / TestCase* / execution envelopes spans all pickles — matching the `multiple-features`
  golden.
  """
  @spec run_features([{String.t(), keyword()}], StepRegistry.t(), keyword()) :: [envelope()]
  def run_features(features, registry, run_opts \\ [])

  def run_features(features, %StepRegistry{} = registry, run_opts) do
    hook_registry = Keyword.get(run_opts, :hooks) || HookRegistry.new()
    ids = Ids.new()

    # Per-run attachment collector: step/hook bodies push attachments onto it via the
    # reserved `:__attach__` world key; the runner drains it after each step/hook and emits
    # the resulting `attachment` envelopes. One process owned by this run; stopped at the end.
    {:ok, attach} = Attach.start_link()

    try do
      do_run_features(features, registry, hook_registry, run_opts, attach, ids)
    after
      Attach.stop(attach)
    end
  end

  defp do_run_features(features, registry, hook_registry, run_opts, attach, ids) do
    # 1. Parser-side envelopes per feature, collecting pickles in document order.
    {parser_envelopes, pickles, ids} = parser_envelopes(features, ids)

    # `--order reverse`: the planning (testCase) and execution order both reverse, while the
    # parser-side envelopes keep document order.
    pickles = if run_opts[:order] == :reverse, do: Enum.reverse(pickles), else: pickles

    # 2. Registration-side envelopes (parameterType / undefinedParameterType / hook / step
    # definition) plus the id-lookup maps later steps reference back.
    {reg, ids} = registration_envelopes(registry, hook_registry, ids)

    # 3. TestRunStarted.
    {test_run_started_id, ids} = Ids.next(ids)
    test_run_started = test_run_started_envelope(test_run_started_id)

    # 4. BeforeAll global hooks, in registration order, right after testRunStarted. A failed
    # BeforeAll fails the run and suppresses all test-case execution (cleanup hooks still run).
    {before_all_envelopes, before_all_ok?, ids} =
      run_global_hooks(:before_test_run, hook_registry, reg.hook_ids, test_run_started_id, attach, ids)

    # 5/6. When a BeforeAll failed, the run is aborted: no TestCase is planned or executed
    # (the pickles are still emitted in the parser section, but they never become test cases).
    # Otherwise plan every pickle into a TestCase — weaving in applicable before/after scenario
    # hooks as `hookId` test steps — then execute each.
    {test_case_envelopes, execution_envelopes, final_failed?, ids} =
      plan_and_execute(
        pickles,
        before_all_ok?,
        registry,
        hook_registry,
        reg,
        run_opts,
        test_run_started_id,
        attach,
        ids
      )

    # 7. AfterAll global hooks, in *reverse* registration order, before testRunFinished.
    {after_all_envelopes, after_all_ok?, _ids} =
      run_global_hooks(:after_test_run, hook_registry, reg.hook_ids, test_run_started_id, attach, ids)

    success = before_all_ok? and after_all_ok? and not final_failed?

    # Final envelope-assembly manifest. The ORDER of this `++` chain is the cucumber-messages
    # ordering contract; every section above is gathered so this stays a readable list.
    parser_envelopes ++
      reg.parameter_type_envelopes ++
      reg.undefined_parameter_type_envelopes ++
      reg.before_hook_defs ++
      reg.step_def_envelopes ++
      reg.after_hook_defs ++
      [test_run_started] ++
      before_all_envelopes ++
      test_case_envelopes ++
      execution_envelopes ++
      after_all_envelopes ++
      [test_run_finished_envelope(test_run_started_id, success)]
  end

  # Step 1: per-feature Source/GherkinDocument/Pickle envelopes (document order), collecting
  # every pickle (also in document order) and threading ids.
  defp parser_envelopes(features, ids) do
    Enum.reduce(features, {[], [], ids}, fn {source, opts}, {env_acc, pickle_acc, ids} ->
      uri = Keyword.get(opts, :uri, "")
      format = Keyword.get(opts, :format, :plain)
      parse_opts = [uri: uri, markdown: format == :markdown]
      document = Gherkin.parse!(source, parse_opts)
      feature_pickles = Gherkin.pickles(source, parse_opts)

      envelopes = [
        Message.source_envelope(uri, source, format),
        Message.gherkin_document_envelope(document)
        | Enum.map(feature_pickles, &Message.pickle_envelope/1)
      ]

      {env_acc ++ envelopes, pickle_acc ++ feature_pickles, ids}
    end)
  end

  # Step 2: the registration-side envelopes, in cucumber-messages registration order:
  #   parameterType* -> undefinedParameterType* -> hook(BEFORE) -> stepDefinition* -> hook(AFTER)
  #
  # Returns a map of the (already-ordered) envelope sections plus the two id-lookup maps the
  # later planning step needs (`hook_ids` and `by_definition`), and the threaded ids.
  #
  #   * Custom parameterType messages each consume an id; undefinedParameterType messages
  #     (emitted for `{type}` defs that referenced an unregistered type) carry none.
  #   * Hook definition envelopes are split into a "before" block (before/beforeAll hooks,
  #     emitted ahead of step defs) and an "after" block (after/afterAll hooks, after them),
  #     mirroring the reference's source-order registration section. The normalizer sorts
  #     each contiguous block by type+tag expression.
  #   * StepDefinition envelopes are one per registered (non-undefined) definition, in
  #     registration order.
  defp registration_envelopes(registry, hook_registry, ids) do
    {parameter_type_envelopes, ids} = parameter_type_envelopes(registry, ids)
    undefined_parameter_type_envelopes = undefined_parameter_type_envelopes(registry)

    {before_hook_defs, after_hook_defs, hook_ids, ids} =
      hook_definition_envelopes(hook_registry, ids)

    {step_def_envelopes, def_ids} = step_definition_envelopes(registry, ids)

    reg = %{
      parameter_type_envelopes: parameter_type_envelopes,
      undefined_parameter_type_envelopes: undefined_parameter_type_envelopes,
      before_hook_defs: before_hook_defs,
      after_hook_defs: after_hook_defs,
      step_def_envelopes: step_def_envelopes,
      hook_ids: hook_ids,
      by_definition: def_ids.by_definition
    }

    {reg, def_ids.ids}
  end

  # Steps 5/6: plan every pickle into a TestCase, then execute each. When a BeforeAll failed
  # the run is aborted, so nothing is planned or executed (the pickles still appear in the
  # parser section but never become test cases). Returns the testCase envelopes, the execution
  # envelopes, whether the *final* attempt of any test case was unsuccessful, and threaded ids.
  defp plan_and_execute(_pickles, false, _registry, _hook_registry, _reg, _run_opts, _trs_id, _attach, ids) do
    {[], [], false, ids}
  end

  defp plan_and_execute(pickles, true, registry, hook_registry, reg, run_opts, test_run_started_id, attach, ids) do
    retry_config = %{
      max: Keyword.get(run_opts, :retry, 0),
      tag_expression: Keyword.get(run_opts, :retry_tag_expression)
    }

    {test_cases, ids} =
      Enum.map_reduce(pickles, ids, fn pickle, ids ->
        plan_test_case(pickle, registry, reg.by_definition, hook_registry, reg.hook_ids, test_run_started_id, ids)
      end)

    {execution_and_flags, ids} =
      Enum.flat_map_reduce(test_cases, ids, fn test_case, ids ->
        {envelopes, final_failed?, ids} = execute_test_case(test_case, retry_config, attach, ids)
        {[{envelopes, final_failed?}], ids}
      end)

    execution = Enum.flat_map(execution_and_flags, fn {envelopes, _} -> envelopes end)
    any_failed? = Enum.any?(execution_and_flags, fn {_, failed?} -> failed? end)
    {Enum.map(test_cases, & &1.envelope), execution, any_failed?, ids}
  end

  @doc "Serialize an envelope list to NDJSON using the gherkin key-sorted serializer."
  @spec to_ndjson([envelope()]) :: String.t()
  def to_ndjson(envelopes), do: Message.to_ndjson(envelopes)

  # ---- ParameterType / UndefinedParameterType envelopes ----------------------

  # One `parameterType` message per *custom* (suite-registered) parameter type, in
  # registration order; each consumes an id. Built-in types are not surfaced.
  defp parameter_type_envelopes(registry, ids) do
    registry
    |> StepRegistry.parameter_types()
    |> Enum.map_reduce(ids, fn type, ids ->
      {id, ids} = Ids.next(ids)
      {parameter_type_envelope(type, id), ids}
    end)
  end

  defp parameter_type_envelope(type, id) do
    %{
      "parameterType" => %{
        "id" => id,
        "name" => type.name,
        "regularExpressions" => type.regexps,
        "preferForRegularExpressionMatch" => type.prefer_for_regexp_match,
        "useForSnippets" => type.use_for_snippets,
        "sourceReference" => source_reference(type)
      }
    }
  end

  # One `undefinedParameterType` message per step definition that referenced an
  # unregistered `{type}`. These carry no id (matching the reference stream).
  defp undefined_parameter_type_envelopes(registry) do
    registry
    |> StepRegistry.undefined_parameter_types()
    |> Enum.map(fn %{name: name, expression: expression} ->
      %{"undefinedParameterType" => %{"name" => name, "expression" => expression}}
    end)
  end

  # ---- Hook definition envelopes ---------------------------------------------

  # Assign an id to every registered hook (registration order) and emit its `hook` envelope.
  # Returns the "before" block (before/beforeAll hook defs), the "after" block (after/afterAll
  # hook defs), and a hook->id map. The before/after split mirrors the reference's source-order
  # registration section: before hooks precede step defs, after hooks follow them.
  defp hook_definition_envelopes(hook_registry, ids) do
    {pairs, ids} =
      hook_registry
      |> HookRegistry.hooks()
      |> Enum.map_reduce(ids, fn hook, ids ->
        {id, ids} = Ids.next(ids)
        {{hook, id}, ids}
      end)

    {before_pairs, after_pairs} =
      Enum.split_with(pairs, fn {hook, _id} ->
        hook.type in [:before_test_case, :before_test_run]
      end)

    to_envelopes = fn list -> Enum.map(list, fn {hook, id} -> hook_definition_envelope(hook, id) end) end
    {to_envelopes.(before_pairs), to_envelopes.(after_pairs), Map.new(pairs), ids}
  end

  defp hook_definition_envelope(hook, id) do
    inner =
      %{"id" => id, "type" => hook_type_string(hook.type), "sourceReference" => source_reference(hook)}
      |> put_unless_nil("name", hook.name)
      |> put_unless_nil("tagExpression", hook.tag_expression)

    %{"hook" => inner}
  end

  defp hook_type_string(:before_test_case), do: "BEFORE_TEST_CASE"
  defp hook_type_string(:after_test_case), do: "AFTER_TEST_CASE"
  defp hook_type_string(:before_test_run), do: "BEFORE_TEST_RUN"
  defp hook_type_string(:after_test_run), do: "AFTER_TEST_RUN"

  # ---- Global (BeforeAll/AfterAll) hooks -------------------------------------

  # Run every global hook of `type` and emit a testRunHookStarted/testRunHookFinished pair
  # per hook. BeforeAll runs in registration order; AfterAll in *reverse*. Every hook runs
  # even if an earlier one failed (cleanup semantics); the boolean reports whether all
  # passed-or-skipped, which feeds testRunFinished.success.
  defp run_global_hooks(type, hook_registry, hook_ids, test_run_started_id, attach, ids) do
    hooks =
      hook_registry
      |> HookRegistry.global_hooks()
      |> Enum.filter(&(&1.type == type))

    hooks = if type == :after_test_run, do: Enum.reverse(hooks), else: hooks

    {envelopes, {all_ok?, ids}} =
      Enum.flat_map_reduce(hooks, {true, ids}, fn hook, {all_ok?, ids} ->
        {status, _world} = run_hook(hook, [], world_with_attach(%{}, attach))
        attachments = Attach.drain(attach)

        {envelopes, ids} =
          test_run_hook_envelopes(test_run_started_id, hook_ids[hook], status, attachments, ids)

        {envelopes, {all_ok? and hook_success?(status), ids}}
      end)

    {envelopes, all_ok?, ids}
  end

  # A global hook's testRunHookStarted, then any attachments emitted while it ran, then its
  # testRunHookFinished — mirroring the scenario-step ordering for `attachment` envelopes.
  defp test_run_hook_envelopes(test_run_started_id, hook_id, status, attachments, ids) do
    {started_id, ids} = Ids.next(ids)

    started = %{
      "testRunHookStarted" => %{
        "testRunStartedId" => test_run_started_id,
        "id" => started_id,
        "hookId" => hook_id,
        "timestamp" => timestamp(Ids.tick(ids))
      }
    }

    {attachment_envelopes, ids} =
      attachment_envelopes(attachments, %{"testRunStartedId" => test_run_started_id}, ids)

    finished = %{
      "testRunHookFinished" => %{
        "testRunHookStartedId" => started_id,
        "timestamp" => timestamp(Ids.tick(ids)),
        "result" => step_result(status)
      }
    }

    {[started] ++ attachment_envelopes ++ [finished], ids}
  end

  defp hook_success?({:failed, _type}), do: false
  defp hook_success?(_other), do: true

  # ---- StepDefinition envelopes ----------------------------------------------

  defp step_definition_envelopes(registry, ids) do
    {envelopes_and_ids, ids} =
      registry
      |> StepRegistry.definitions()
      |> Enum.reject(&(&1.pattern_kind == :undefined))
      |> Enum.map_reduce(ids, fn definition, ids ->
        {id, ids} = Ids.next(ids)
        {{definition, id, step_definition_envelope(definition, id)}, ids}
      end)

    by_definition =
      envelopes_and_ids
      |> Enum.map(fn {definition, id, _env} -> {definition, id} end)
      |> Map.new()

    envelopes = Enum.map(envelopes_and_ids, fn {_def, _id, env} -> env end)
    {envelopes, %{ids: ids, by_definition: by_definition}}
  end

  defp step_definition_envelope(definition, id) do
    %{
      "stepDefinition" => %{
        "id" => id,
        "pattern" => %{
          "source" => definition.source,
          "type" => pattern_type(definition.pattern_kind)
        },
        "sourceReference" => source_reference(definition)
      }
    }
  end

  defp pattern_type(:cucumber_expression), do: "CUCUMBER_EXPRESSION"
  defp pattern_type(:regular_expression), do: "REGULAR_EXPRESSION"

  defp source_reference(%{uri: nil}), do: %{}

  defp source_reference(%{uri: uri, line: nil}), do: %{"uri" => uri}

  defp source_reference(%{uri: uri, line: line}),
    do: %{"uri" => uri, "location" => %{"line" => line}}

  # ---- TestCase planning -----------------------------------------------------

  defp plan_test_case(pickle, registry, def_ids, hook_registry, hook_ids, test_run_started_id, ids) do
    {test_case_id, ids} = Ids.next(ids)

    pickle_tags = Enum.map(pickle.tags, & &1.name)
    {before_hooks, after_hooks} = applicable_scenario_hooks(hook_registry, pickle_tags)

    # Before scenario hooks -> hook test steps; pickle steps -> step test steps; After
    # scenario hooks -> hook test steps. Each gets its own test step id, in this order.
    {before_planned, ids} = plan_hook_steps(before_hooks, hook_ids, ids)
    {step_planned, ids} = plan_pickle_steps(pickle.steps, registry, def_ids, ids)
    {after_planned, ids} = plan_hook_steps(after_hooks, hook_ids, ids)

    planned_steps = before_planned ++ step_planned ++ after_planned
    test_steps_json = Enum.map(planned_steps, &test_step_json/1)

    envelope = %{
      "testCase" => %{
        "id" => test_case_id,
        "pickleId" => pickle.id,
        "testRunStartedId" => test_run_started_id,
        "testSteps" => test_steps_json
      }
    }

    {%{
       id: test_case_id,
       tags: pickle_tags,
       before_hooks: before_planned,
       steps: step_planned,
       after_hooks: after_planned,
       envelope: envelope
     }, ids}
  end

  # Scenario hooks that apply to a pickle: before hooks (registration order) and after hooks
  # (registration order), each filtered by its tag expression against the pickle's tags.
  defp applicable_scenario_hooks(hook_registry, pickle_tags) do
    hooks =
      hook_registry
      |> HookRegistry.scenario_hooks()
      |> Enum.filter(&hook_applies?(&1, pickle_tags))

    Enum.split_with(hooks, &(&1.type == :before_test_case))
  end

  defp hook_applies?(%{tag_expression: nil}, _tags), do: true
  defp hook_applies?(%{tag_expression: expr}, tags), do: Cabbage.TagExpression.evaluate(expr, tags)

  defp plan_hook_steps(hooks, hook_ids, ids) do
    Enum.map_reduce(hooks, ids, fn hook, ids ->
      {test_step_id, ids} = Ids.next(ids)
      {%{id: test_step_id, kind: :hook, hook: hook, hook_id: hook_ids[hook]}, ids}
    end)
  end

  defp plan_pickle_steps(pickle_steps, registry, def_ids, ids) do
    Enum.map_reduce(pickle_steps, ids, fn pickle_step, ids ->
      {test_step_id, ids} = Ids.next(ids)
      matches = Matcher.matches(registry, pickle_step.text)

      {%{
         id: test_step_id,
         kind: :step,
         pickle_step: pickle_step,
         matches: matches,
         definition_ids: Enum.map(matches, fn m -> Map.fetch!(def_ids, m.definition) end)
       }, ids}
    end)
  end

  defp test_step_json(%{kind: :hook} = planned_step) do
    %{"id" => planned_step.id, "hookId" => planned_step.hook_id}
  end

  defp test_step_json(%{kind: :step} = planned_step) do
    %{
      "id" => planned_step.id,
      "pickleStepId" => planned_step.pickle_step.id,
      "stepDefinitionIds" => planned_step.definition_ids,
      "stepMatchArgumentsLists" => step_match_arguments_lists(planned_step.matches)
    }
  end

  # undefined: no matches -> empty list. defined/ambiguous: one entry per matching def.
  defp step_match_arguments_lists(matches) do
    Enum.map(matches, fn match -> %{"stepMatchArguments" => match.arguments} end)
  end

  # ---- TestCase execution ----------------------------------------------------

  # Execute a test case, re-running it as long as it FAILS and there are retry attempts
  # left (cucumber-js retry semantics, CCK `retry*` areas). Each attempt emits its own
  # `testCaseStarted` (same `testCaseId`, incrementing 0-based `attempt`), re-emits the step
  # envelopes, and a `testCaseFinished` whose `willBeRetried` is `true` for every non-final
  # failed attempt. Only a FAILED case retries — AMBIGUOUS/PENDING/UNDEFINED never pass on a
  # re-run, so they are attempted exactly once. Returns the accumulated envelopes, whether
  # the *final* attempt was unsuccessful (any non-PASSED/SKIPPED step → feeds run success),
  # and the threaded ids.
  defp execute_test_case(test_case, retry_config, attach, ids) do
    max_retries = if retry_eligible?(test_case, retry_config), do: retry_config.max, else: 0
    run_attempts(test_case, attach, ids, 0, max_retries, [])
  end

  # A test case is retry-eligible when retries are configured and (if a tag expression was
  # given) the pickle's tags match it. The status-based gate (only FAILED retries) is applied
  # per attempt below.
  defp retry_eligible?(_test_case, %{max: max}) when max <= 0, do: false
  defp retry_eligible?(_test_case, %{tag_expression: nil}), do: true

  defp retry_eligible?(test_case, %{tag_expression: expr}),
    do: Cabbage.TagExpression.evaluate(expr, test_case.tags)

  defp run_attempts(test_case, attach, ids, attempt, max_retries, acc_envelopes) do
    {envelopes, failed?, unsuccessful?, ids} =
      run_attempt(test_case, attach, ids, attempt, attempt < max_retries)

    acc_envelopes = acc_envelopes ++ envelopes

    if failed? and attempt < max_retries do
      run_attempts(test_case, attach, ids, attempt + 1, max_retries, acc_envelopes)
    else
      {acc_envelopes, unsuccessful?, ids}
    end
  end

  # Run one attempt of a test case. `will_retry?` is whether this attempt *would* be retried
  # if it fails (used directly as `willBeRetried` since the loop only continues on a failure).
  # Returns `{envelopes, failed?, unsuccessful?, ids}` where `failed?` means a FAILED step
  # occurred (retry trigger) and `unsuccessful?` means any non-PASSED/SKIPPED step occurred.
  defp run_attempt(test_case, attach, ids, attempt, will_retry?) do
    {test_case_started_id, ids} = Ids.next(ids)
    started = test_case_started_envelope(test_case_started_id, test_case.id, attempt, ids)

    # Thread two skip-propagation flags across the scenario's Before hooks + steps
    # (cucumber-js semantics, see the CCK `failedish-combinations` and `hooks-skipped`
    # samples):
    #
    #   * `failed_ish?`    — a prior step/hook reported a non-PASSED status. This skips later
    #                        *executable* steps (a single match / a runnable hook) but leaves
    #                        UNDEFINED/AMBIGUOUS steps reporting their own status.
    #   * `intrinsic_skip?` — a prior step/hook's *intrinsic* status was SKIPPED (a `"skipped"`
    #                        return or a raised `Cabbage.SkippedError`). A real skip cascades
    #                        to *every* later step in this chain, even undefined/ambiguous ones.
    #
    # Before hooks and pickle steps share one skip chain; After hooks always run, each in its
    # own fresh chain (a skipped/failing After does not cascade to later After hooks). The
    # `attach` collector is drained per step, so each attempt starts with a clean slate — no
    # attachment leaks from a prior attempt.
    acc0 = %{
      envelopes: [],
      world: %{},
      failed_ish?: false,
      intrinsic_skip?: false,
      reported: [],
      ids: ids,
      attach: attach
    }

    acc = execute_steps(test_case, test_case_started_id, acc0)

    failed? = Enum.any?(acc.reported, &(&1 == :failed))
    unsuccessful? = Enum.any?(acc.reported, &(&1 not in [:passed, :skipped]))
    will_be_retried? = failed? and will_retry?

    finished = test_case_finished_envelope(test_case_started_id, will_be_retried?, acc.ids)
    {[started] ++ acc.envelopes ++ [finished], failed?, unsuccessful?, acc.ids}
  end

  # Run every planned step of one attempt through the accumulator. Before hooks and pickle
  # steps share one skip chain (a failed/skipped earlier one propagates per `execute_step`);
  # After hooks always run, each in its own fresh chain (a skipped/failing After does not
  # cascade to later After hooks).
  defp execute_steps(test_case, test_case_started_id, acc) do
    acc =
      Enum.reduce(test_case.before_hooks ++ test_case.steps, acc, fn planned, acc ->
        execute_step(planned, test_case_started_id, acc)
      end)

    Enum.reduce(test_case.after_hooks, acc, fn planned, acc ->
      fresh = %{acc | failed_ish?: false, intrinsic_skip?: false}
      execute_step(planned, test_case_started_id, fresh)
    end)
  end

  # Execute (or skip) one planned step or hook, returning the updated accumulator.
  defp execute_step(planned, test_case_started_id, acc) do
    {intrinsic, new_world} = intrinsic_status(planned, acc.world, acc.attach)
    reported = report_status(intrinsic, acc)

    # Whatever the body attached while running (drained even on a failed/raised step, since
    # the collector lives outside the body's return value). A *skipped* step never ran, so
    # the collector holds nothing for it.
    attachments = Attach.drain(acc.attach)

    suggestions =
      if reported == :undefined,
        do: suggestion_snippets(planned.pickle_step.text),
        else: []

    {step_envelopes, ids} =
      emit_step(planned, test_case_started_id, acc.ids, reported, suggestions, attachments)

    %{
      acc
      | envelopes: acc.envelopes ++ step_envelopes,
        world: new_world,
        ids: ids,
        reported: acc.reported ++ [bare_status(reported)],
        failed_ish?: acc.failed_ish? or reported != :passed,
        intrinsic_skip?: acc.intrinsic_skip? or intrinsic_skip?(intrinsic)
    }
  end

  # The status atom without its (optional) exception-type tuple, for the retry decision and
  # run-success determination.
  defp bare_status({status, _type}), do: status
  defp bare_status(status), do: status

  # The status a hook would have *on its own* — hooks have no match concept, they just run.
  defp intrinsic_status(%{kind: :hook} = planned, world, attach),
    do: run_hook(planned.hook, [], world_with_attach(world, attach))

  # The status a step would have *on its own*, ignoring prior steps: UNDEFINED when no
  # definition matches, AMBIGUOUS when more than one does, otherwise the run result.
  defp intrinsic_status(%{kind: :step} = planned_step, world, attach) do
    case planned_step.matches do
      [] -> {:undefined, world}
      [match] -> run_step(match, planned_step.pickle_step, world_with_attach(world, attach))
      _ambiguous -> {:ambiguous, world}
    end
  end

  # The world a step/hook body sees, carrying the attachment collector pid under the
  # reserved `:__attach__` key so `Cabbage.Messages.Attach.attach/3` can find it.
  defp world_with_attach(world, attach), do: Map.put(world, :__attach__, attach)

  # Apply the skip-propagation rule to turn an intrinsic status into the reported one.
  # A real (intrinsic) skip earlier cascades to everything; otherwise a prior failed-ish
  # step only skips later *executable* steps, leaving undefined/ambiguous intact.
  defp report_status(_intrinsic, %{intrinsic_skip?: true}), do: :skipped

  defp report_status(intrinsic, %{failed_ish?: true}) do
    if executable?(intrinsic), do: :skipped, else: intrinsic
  end

  defp report_status(intrinsic, _acc), do: intrinsic

  # Executable steps are the ones that actually invoke a step definition; undefined and
  # ambiguous steps never run, so they are not skippable by a prior failed-ish step.
  defp executable?(:undefined), do: false
  defp executable?(:ambiguous), do: false
  defp executable?(_runnable), do: true

  # Only a genuine SKIPPED outcome (return value or raised SkippedError) cascades fully.
  defp intrinsic_skip?(:skipped), do: true
  defp intrinsic_skip?({:skipped, _type}), do: true
  defp intrinsic_skip?(_other), do: false

  defp run_step(match, pickle_step, world) do
    step_argument = step_argument(pickle_step)
    result = apply_step_fun(match.definition.fun, match.values, step_argument, world)
    classify_outcome(result, world)
  rescue
    error -> rescue_outcome(error, world)
  end

  # A hook runs its 0..3-arity function the same way a step does (no match args / step
  # argument), and maps its return/raise through the same outcome protocol.
  defp run_hook(hook, args, world) do
    result = apply_step_fun(hook.fun, args, nil, world)
    classify_outcome(result, world)
  rescue
    error -> rescue_outcome(error, world)
  end

  defp classify_outcome(result, world) do
    case result do
      "pending" -> {:pending, world}
      :pending -> {:pending, world}
      "skipped" -> {:skipped, world}
      :skipped -> {:skipped, world}
      {:ok, new_world} when is_map(new_world) -> {:passed, new_world}
      _ -> {:passed, world}
    end
  end

  # Dedicated pending/skip exceptions carry the reference type names so the message stream
  # distinguishes "pending via exception" from "pending via return value".
  defp rescue_outcome(error, world) do
    case error do
      %Cabbage.PendingError{} -> {{:pending, "PendingException"}, world}
      %Cabbage.SkippedError{} -> {{:skipped, "SkippedException"}, world}
      _ -> {{:failed, exception_type(error)}, world}
    end
  end

  # Map an Elixir exception to the cucumber-messages `exception.type` the goldens carry.
  # Assertion-style failures (a failed `^pattern =` match or an ExUnit assertion) are
  # reported as `AssertionError`; any other raise is a generic `Error`, matching how
  # fake-cucumber labels thrown JS errors. (`message`/`stackTrace` are dropped by the
  # normalizer, so only the type is compared.)
  defp exception_type(%MatchError{}), do: "AssertionError"
  defp exception_type(%{__struct__: ExUnit.AssertionError}), do: "AssertionError"
  defp exception_type(_other), do: "Error"

  # Step funs may accept arity 0..3. We pass (args, step_argument, world) and adapt.
  defp apply_step_fun(fun, args, step_argument, world) do
    case Function.info(fun, :arity) do
      {:arity, 0} -> fun.()
      {:arity, 1} -> fun.(args)
      {:arity, 2} -> fun.(args, step_argument)
      {:arity, 3} -> fun.(args, step_argument, world)
    end
  end

  defp step_argument(%{argument: {:data_table, %{rows: rows}}}), do: {:data_table, rows}
  defp step_argument(%{argument: {:doc_string, %{content: content}}}), do: {:doc_string, content}
  defp step_argument(_), do: nil

  defp emit_step(planned_step, test_case_started_id, ids, status, suggestion_snippets, attachments) do
    started = test_step_started_envelope(test_case_started_id, planned_step.id, ids)

    {suggestion_envelopes, ids} =
      emit_suggestions(planned_step, suggestion_snippets, ids)

    # Attachments emitted by the body sit between testStepStarted and testStepFinished,
    # carrying this step's testCaseStartedId/testStepId (mirroring fake-cucumber).
    refs = %{"testCaseStartedId" => test_case_started_id, "testStepId" => planned_step.id}
    {attachment_envelopes, ids} = attachment_envelopes(attachments, refs, ids)

    finished =
      test_step_finished_envelope(test_case_started_id, planned_step.id, status, ids)

    {[started] ++ suggestion_envelopes ++ attachment_envelopes ++ [finished], ids}
  end

  # Build one `attachment` envelope per drained attachment, in push order. `refs` carries
  # the id keys to attach (`testCaseStartedId`/`testStepId` for scenario steps, or
  # `testRunStartedId` for global hooks); all are dropped by the normalizer.
  defp attachment_envelopes(attachments, refs, ids) do
    # An `attachment` envelope carries no `id` (only a dropped timestamp), so it does not
    # consume an id — `ids` threads through unchanged.
    {Enum.map(attachments, fn attachment -> attachment_envelope(attachment, refs, ids) end), ids}
  end

  defp attachment_envelope(attachment, refs, ids) do
    inner =
      refs
      |> Map.merge(%{
        "body" => attachment.body,
        "contentEncoding" => content_encoding_string(attachment.content_encoding),
        "mediaType" => attachment.media_type,
        "timestamp" => timestamp(Ids.tick(ids))
      })
      |> put_unless_nil("fileName", Map.get(attachment, :file_name))

    %{"attachment" => inner}
  end

  defp content_encoding_string(:identity), do: "IDENTITY"
  defp content_encoding_string(:base64), do: "BASE64"

  defp emit_suggestions(_planned_step, [], ids), do: {[], ids}

  defp emit_suggestions(planned_step, snippets, ids) do
    {id, ids} = Ids.next(ids)

    envelope = %{
      "suggestion" => %{
        "id" => id,
        "pickleStepId" => planned_step.pickle_step.id,
        "snippets" => snippets
      }
    }

    {[envelope], ids}
  end

  # cucumber-js generates one snippet per plausible parameter-type interpretation of the
  # undefined step text. Normalization strips snippet `code`/`language` (see
  # `Cabbage.Messages.Normalizer`), so only the snippet COUNT is compared against the golden.
  #
  # This count is INTENTIONALLY corpus-fitted to the CCK `undefined`/`pending`/`skipped`
  # samples rather than derived: those samples only ever exercise the two cases below, so a
  # heuristic is exact for the goldens we grade against and avoids reimplementing
  # cucumber-js's full snippet generator. A digit anywhere in the text yields two snippets
  # (the `{int}` and `{float}` interpretations); any other text yields one.
  #
  # What would break this: an undefined step whose text supports a *different* number of
  # parameter-type interpretations than 1-or-2 (e.g. multiple numeric tokens, or a custom
  # parameter type whose regex matches part of the text). A CCK sample like that would force
  # deriving the count from the enumerated interpretations instead of from this digit check.
  defp suggestion_snippets(text) do
    count = if Regex.match?(~r/\d/, text), do: 2, else: 1
    for _ <- 1..count, do: %{"code" => "", "language" => "elixir"}
  end

  # ---- Run-structure envelope builders ---------------------------------------

  defp test_run_started_envelope(id) do
    %{"testRunStarted" => %{"id" => id, "timestamp" => timestamp(0)}}
  end

  defp test_run_finished_envelope(test_run_started_id, success) do
    %{
      "testRunFinished" => %{
        "testRunStartedId" => test_run_started_id,
        "timestamp" => timestamp(0),
        "success" => success
      }
    }
  end

  defp test_case_started_envelope(id, test_case_id, attempt, ids) do
    %{
      "testCaseStarted" => %{
        "id" => id,
        "testCaseId" => test_case_id,
        "attempt" => attempt,
        "timestamp" => timestamp(Ids.tick(ids))
      }
    }
  end

  defp test_case_finished_envelope(test_case_started_id, will_be_retried?, ids) do
    %{
      "testCaseFinished" => %{
        "testCaseStartedId" => test_case_started_id,
        "timestamp" => timestamp(Ids.tick(ids)),
        "willBeRetried" => will_be_retried?
      }
    }
  end

  defp test_step_started_envelope(test_case_started_id, test_step_id, ids) do
    %{
      "testStepStarted" => %{
        "testCaseStartedId" => test_case_started_id,
        "testStepId" => test_step_id,
        "timestamp" => timestamp(Ids.tick(ids))
      }
    }
  end

  defp test_step_finished_envelope(test_case_started_id, test_step_id, status, ids) do
    %{
      "testStepFinished" => %{
        "testCaseStartedId" => test_case_started_id,
        "testStepId" => test_step_id,
        "testStepResult" => step_result(status),
        "timestamp" => timestamp(Ids.tick(ids))
      }
    }
  end

  # A cucumber-messages `TestStepResult`/`Hook` result: a status, a (dropped) duration, and
  # an optional `exception` (present for failures and exception-raised pending/skipped).
  defp step_result(status) do
    %{"status" => status_string(status), "duration" => timestamp(0)}
    |> maybe_put_exception(status)
  end

  # Failed steps, and pending/skipped raised *via an exception*, carry an `exception`
  # object whose `type` matches the reference (`Error`/`AssertionError`, `PendingException`,
  # `SkippedException`). Pending/skipped reached via a *return value* carry none.
  defp maybe_put_exception(result, {status, type}) when status in [:failed, :pending, :skipped],
    do: Map.put(result, "exception", %{"type" => type})

  defp maybe_put_exception(result, _status), do: result

  defp status_string({:failed, _type}), do: "FAILED"
  defp status_string({:pending, _type}), do: "PENDING"
  defp status_string({:skipped, _type}), do: "SKIPPED"
  defp status_string(:passed), do: "PASSED"
  defp status_string(:undefined), do: "UNDEFINED"
  defp status_string(:pending), do: "PENDING"
  defp status_string(:skipped), do: "SKIPPED"
  defp status_string(:ambiguous), do: "AMBIGUOUS"

  defp timestamp(_n), do: %{"seconds" => 0, "nanos" => 0}
end
