Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureTagsTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  describe "Runns scenarios bassed on tags" do
    test "runs all scenarios when no tag filter is provided" do
      defmodule FeatureTagsTest do
        use Cabbage.Feature, file: "tags.feature"

        defwhen ~r/^I provide When$/, _vars, _state do
        end

        defthen ~r/^I provide Then$/, _vars, _state do
        end
      end

      Application.put_env(:cabbage, :global_tags, :global_cabbage_tag)

      defmodule FeatureTagsTestWithTags do
        use Cabbage.Feature, file: "tags.feature", tags: [:cabbage_style_tag]
        @moduletag :ex_unit_style_tag

        defwhen ~r/^I provide When$/, _vars, _state do
        end

        defthen ~r/^I provide Then$/, _vars, _state do
        end
      end

      modules = [FeatureTagsTest, FeatureTagsTestWithTags]

      # Empty because loaded
      {result, _output} = run_with_filter([], [])
      assert result == %{failures: 0, skipped: 0, total: 8, excluded: 0}

      {result, _output} = run_with_filter([exclude: [:test], include: [:some_tag]], modules)
      assert result == %{failures: 0, skipped: 0, total: 8, excluded: 4}

      {result, _output} = run_with_filter([exclude: [:test], include: [:another_tag]], modules)
      assert result == %{failures: 0, skipped: 0, total: 8, excluded: 6}

      {result, _output} = run_with_filter([exclude: [:test], include: [tag_with_value: "my_value"]], modules)
      assert result == %{failures: 0, skipped: 0, total: 8, excluded: 6}

      {result, _output} = run_with_filter([exclude: [:test], include: [:ex_unit_style_tag]], modules)
      assert result == %{failures: 0, skipped: 0, total: 8, excluded: 4}

      {result, _output} = run_with_filter([exclude: [:test], include: [:cabbage_style_tag]], modules)
      assert result == %{failures: 0, skipped: 0, total: 8, excluded: 4}

      {result, _output} = run_with_filter([exclude: [:test], include: [:global_cabbage_tag]], modules)
      assert result == %{failures: 0, skipped: 0, total: 8, excluded: 4}
    end
  end

  defp run_with_filter(filters, cases) do
    Enum.each(cases, &ExUnit.Server.add_sync_module/1)
    ExUnit.Server.modules_loaded()

    opts =
      ExUnit.configuration()
      |> Keyword.merge(filters)
      |> Keyword.merge(colors: [enabled: false])

    output = capture_io(fn -> Process.put(:capture_result, ExUnit.Runner.run(opts, nil)) end)
    {Process.get(:capture_result), output}
  end
end
