defmodule Cabbage.ExUnit.CaseTemplate do
  use ExUnit.CaseTemplate

  using do
    quote do
      setup_all do
        {:ok, %{case_template: unquote(__MODULE__)}}
      end
    end
  end

  setup do
    {:ok, %{starting: :state}}
  end
end
