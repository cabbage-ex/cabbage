defmodule MissingStepError do
  @moduledoc """
  Raises an error, because a feature step is missing its implementation.

  The message of the error will give the user a useful code snippet where
  variables in feature steps are converted to regex capture groups.
  """

  defexception [:message]

  @number_regex ~r/(^|\s)\d+(\s|$)/
  @single_quote_regex ~r/'[^']+'/
  @double_quote_regex ~r/"[^"]+"/

  def exception(step_text: step_text, step_type: step_type) do
    converted_step_text =
      step_text
      |> multi_num(1, &match_numbers?(&1))
      |> convert_double_quote_strings()
      |> convert_single_quote_strings()

    message = """
    Please add a matching step for:
    "#{step_type} #{step_text}"

      def#{step_type |> String.downcase} ~r/^#{converted_step_text}$/, vars, state do
        # Your implementation here
      end
    """

    %__MODULE__{message: message}
  end

  defp match_numbers?(step_text) do
    String.match?(step_text, @number_regex)
  end

  defp convert_numbers(step_text, count) do
    Regex.replace(@number_regex, step_text, ~s/\\1(?<number_#{count}>\\d+)\\2/, global: false)
  end

  defp convert_double_quote_strings(step_text) do
    Regex.replace(@double_quote_regex, step_text, ~s/"(?<string>[^"]+)"/)
  end

  defp convert_single_quote_strings(step_text) do
    Regex.replace(@single_quote_regex, step_text, ~s/'(?<string>[^']+)'/)
  end

  defp multi_num(step_text, _count, false), do: step_text
  defp multi_num(step_text, count, _run_result) do
    converted_step_text = convert_numbers(step_text, count)
    multi_num(converted_step_text, count + 1, match_numbers?(converted_step_text))
  end

end
