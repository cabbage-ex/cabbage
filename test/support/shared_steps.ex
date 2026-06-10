defmodule Cabbage.SharedSteps do
  @moduledoc false
  use Cabbage.Steps

  defstep ~r/^I provide Given$/, %{count: count} do
    {:ok, %{count: count + 1}}
  end

  defstep ~r/^I provide And$/, %{count: count} do
    {:ok, %{count: count + 1}}
  end

  defstep ~r/^I provide When$/, %{count: count} do
    {:ok, %{count: count + 1}}
  end
end
