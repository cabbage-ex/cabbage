defmodule Cabbage.MissingStepAdvisor do

  def raise(step_text, step_type) do

    converted_step_text = convert_numbers_to_regex_capture_group(step_text)

    raise """
    Please add a matching step for:
    "#{step_type} #{step_text}"

      def#{step_type |> String.downcase} ~r/^#{converted_step_text}$/, vars, state do
        # Your implementation here
      end
    """
  end

  defp convert_numbers_to_regex_capture_group(step_text) do
    Regex.replace(~r/(\s)\d+(\s|$)/, step_text, "\\1(?<number>\d+)\\2")
  end

end
