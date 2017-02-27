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
      |> convert_multiples(&match_numbers?/1, &convert_numbers/2)
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

  defp convert_multiples(step_text, match_fun, convert_fun) do
    convert_multiples(step_text, match_fun, convert_fun, 1)
  end

  defp convert_multiples(step_text, match_fun, convert_fun, count) do
    case match_fun.(step_text) do
      false ->
        step_text
      _ ->
        convert_multiples(convert_fun.(step_text, count), match_fun, convert_fun, count + 1)
    end
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
end
