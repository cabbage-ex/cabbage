defmodule Cabbage.MissingStepAdvisor do

  def raise(step_text, step_type) do

    converted_step_text =
      step_text
      |> convert_numbers()
      |> convert_double_quote_strings()
      |> convert_single_quote_strings()

    raise """
    Please add a matching step for:
    "#{step_type} #{step_text}"

      def#{step_type |> String.downcase} ~r/^#{converted_step_text}$/, vars, state do
        # Your implementation here
      end
    """
  end

  defp convert_numbers(step_text) do
    Regex.replace(~r/(\s)\d+(\s|$)/, step_text, ~s/\\1(?<number>\\d+)\\2/)
  end

  defp convert_double_quote_strings(step_text) do
    Regex.replace(~r/"(?<string>[^"]+)"/, step_text, ~s/"(?<string>[^"]+)"/)
  end

  defp convert_single_quote_strings(step_text) do
    Regex.replace(~r/'(?<string>[^']+)'/, step_text, ~s/'(?<string>[^']+)'/)
  end

end
