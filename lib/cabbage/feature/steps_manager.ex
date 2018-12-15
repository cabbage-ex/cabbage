defmodule Cabbage.Feature.StepsManager do
  alias Gherkin.Elements.{Feature, Scenario, Steps}

  def find_implementations_for_step(%Steps.Given{text: text} = step, implemented_steps) do
    find_implementations_for_step(:given, text, implemented_steps)
  end

  def find_implementations_for_step(%Steps.When{text: text} = step, implemented_steps) do
    find_implementations_for_step(:when, text, implemented_steps)
  end

  def find_implementations_for_step(%Steps.Then{text: text} = step, implemented_steps) do
    find_implementations_for_step(:then, text, implemented_steps)
  end

  defp find_implementations_for_step(type, text, implemented_steps) when is_list(implemented_steps) do
    Enum.filter(implemented_steps, &is_correct_step?(&1, {type, text}))
  end

  defp find_implementations_for_step(type, text, implemented_step) do
    is_correct_step?(implemented_step, {type, text})
  end

  defp is_correct_step?({search_type, regex, _parameters, _state, _block}, {type, text}) do
    search_type == type && Regex.match?(regex, text)
  end
end
