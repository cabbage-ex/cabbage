defmodule Cabbage.Messages.HookRegistryTest do
  @moduledoc """
  Unit tests for the hook registry backing the message-emitting runner.

  These pin the structural contract the runner relies on: hooks preserve registration
  order, carry optional name/tag-expression/source metadata, and can be partitioned into
  the scenario (`BEFORE_TEST_CASE`/`AFTER_TEST_CASE`) and global
  (`BEFORE_TEST_RUN`/`AFTER_TEST_RUN`) groups.
  """
  use ExUnit.Case, async: true

  alias Cabbage.Messages.HookRegistry

  test "new/0 is empty" do
    assert HookRegistry.hooks(HookRegistry.new()) == []
  end

  test "add/4 preserves registration order across hook types" do
    registry =
      HookRegistry.new()
      |> HookRegistry.add(:before_test_case, fn -> :ok end)
      |> HookRegistry.add(:before_test_run, fn -> :ok end)
      |> HookRegistry.add(:after_test_case, fn -> :ok end)
      |> HookRegistry.add(:after_test_run, fn -> :ok end)

    assert Enum.map(HookRegistry.hooks(registry), & &1.type) ==
             [:before_test_case, :before_test_run, :after_test_case, :after_test_run]
  end

  test "add/4 records name, tag expression, and source reference" do
    registry =
      HookRegistry.new()
      |> HookRegistry.add(:before_test_case, fn -> :ok end,
        name: "a named hook",
        tag: "@smoke",
        uri: "samples/x/x.ts",
        line: 3
      )

    [hook] = HookRegistry.hooks(registry)
    assert hook.name == "a named hook"
    assert hook.tag_expression == "@smoke"
    assert hook.uri == "samples/x/x.ts"
    assert hook.line == 3
  end

  test "scenario_hooks/1 and global_hooks/1 partition by group, preserving order" do
    registry =
      HookRegistry.new()
      |> HookRegistry.add(:before_test_run, fn -> :ok end, name: "ba1")
      |> HookRegistry.add(:before_test_case, fn -> :ok end, name: "b1")
      |> HookRegistry.add(:after_test_run, fn -> :ok end, name: "aa1")
      |> HookRegistry.add(:after_test_case, fn -> :ok end, name: "a1")

    assert Enum.map(HookRegistry.scenario_hooks(registry), & &1.name) == ["b1", "a1"]
    assert Enum.map(HookRegistry.global_hooks(registry), & &1.name) == ["ba1", "aa1"]
  end
end
