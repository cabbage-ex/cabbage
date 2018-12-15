Code.require_file("test_helper.exs", __DIR__)

defmodule Cabbage.FeatureTestTest do
  use ExUnit.Case

  test "can use custom template" do
    defmodule CustomTemplate do
      use ExUnit.CaseTemplate

      using do
        quote do
          setup_all do
            {:ok, %{case_template: unquote(__MODULE__)}}
          end
        end
      end
    end

    defmodule FeatureTimeoutTest do
      use Cabbage.FeatureCase, feature: "simplest.feature", test_case: CustomTemplate

      defthen ~r/^I provide Then$/, _vars, state do
        assert state.case_template == CustomTemplate
      end
    end

    {result, _output} = CabbageTestHelper.run()
    assert result == %{failures: 0, skipped: 0, total: 1, excluded: 0}
  end
end
