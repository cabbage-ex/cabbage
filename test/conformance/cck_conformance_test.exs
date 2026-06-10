defmodule Cabbage.Conformance.CCKTest do
  @moduledoc """
  Drives the message-emitting runner (`Cabbage.Messages`) over the vendored Cucumber
  Compatibility Kit samples and asserts each targeted area's normalized envelope stream
  equals its golden.

  Tagged `:conformance` so it is excluded from the default `mix test` run (which must stay
  green). Run with `mix conformance` or `mix test --only conformance`. The plain scoreboard
  is `mix conformance.cck`.
  """
  use ExUnit.Case, async: true

  @moduletag :conformance

  alias Cabbage.Conformance.CCK.Runner

  # Areas that currently pass end-to-end. A regression here fails loudly.
  @passing ~w(
    minimal empty backgrounds data-tables doc-strings cdata rules rules-backgrounds examples-tables
    examples-tables-undefined
    multiple-features multiple-features-reversed unused-steps undefined pending skipped ambiguous
    all-statuses failedish-combinations stack-traces pending-exception skipped-exception
    parameter-types regular-expression unknown-parameter-type
    hooks hooks-named hooks-conditional hooks-skipped hooks-undefined
    global-hooks global-hooks-beforeall-error global-hooks-afterall-error skipped-failing-hook
    attachments examples-tables-attachment hooks-attachment global-hooks-attachments
    retry retry-ambiguous retry-pending retry-undefined
  )

  # Areas blocked on gherkin-parser feature gaps (NOT on the runner):
  #   * markdown — the Markdown-with-Gherkin dialect treats a leading markdown table line as
  #     the Feature description; our gherkin fork drops it (envelope counts and the 2 `log`
  #     attachments now match exactly — only `feature.description` diverges). Tracked as a
  #     gherkin-fork follow-up; the attachments wave confirmed it is the *sole* remaining gap.
  @blocked_on_gherkin ~w(markdown)

  for sample <- @passing do
    test "CCK conformance: #{sample}" do
      sample = unquote(sample)

      case Runner.compare(sample) do
        {:ok, count} -> assert count > 0
        {:error, reason} -> flunk("#{sample} diverged from golden:\n#{reason}")
      end
    end
  end

  for sample <- @blocked_on_gherkin do
    @tag :skip
    test "CCK conformance: #{sample} (blocked on gherkin parser)" do
      sample = unquote(sample)
      assert {:ok, _} = Runner.compare(sample)
    end
  end

  test "every targeted sample is accounted for" do
    assert Enum.sort(Runner.samples()) == Enum.sort(@passing ++ @blocked_on_gherkin)
  end
end
