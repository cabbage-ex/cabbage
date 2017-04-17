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
      |> convert_nums()
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

  defp convert_nums(step_text) do
    @number_regex
    |> Regex.split(step_text)
    |> join_regex_split(1, &get_number_string(&1))
  end

  defp convert_double_quote_strings(step_text) do
    @double_quote_regex
    |> Regex.split(step_text)
    |> join_regex_split(1, &get_double_quote_string(&1))
  end

  defp convert_single_quote_strings(step_text) do
    @single_quote_regex
    |> Regex.split(step_text)
    |> join_regex_split(1, &get_single_quote_string(&1))
  end

  defp join_regex_split(matches, count, get_string_fun, acc \\ "")

  defp join_regex_split([], _count, _get_string_fun, acc), do: String.trim(acc)
  defp join_regex_split([head | []], _count, _get_string_fun, acc), do: String.trim(acc <> head)

  defp join_regex_split([head | tail], count, get_string_fun, acc) do
    join_regex_split(tail, count + 1, get_string_fun, acc <> head <> get_string_fun.(count))
  end

  defp get_number_string(count),       do: ~s/ (?<number_#{count}>\\d+) /
  defp get_single_quote_string(count), do: ~s/'(?<string_#{count}>[^']+)'/
  defp get_double_quote_string(count), do: ~s/"(?<string_#{count}>[^"]+)"/
end
