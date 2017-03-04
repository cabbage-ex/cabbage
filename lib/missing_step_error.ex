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
    join_num_split(Regex.split(@number_regex, step_text), 1, "")
  end

  defp join_num_split([], _count, acc), do: String.trim(acc)
  defp join_num_split([head | []], count, acc) do
    join_num_split([], count + 1, acc <> head)
  end
  defp join_num_split([head | tail], count, acc) do
    join_num_split(tail, count + 1, acc <> head <> ~s/ (?<number_#{count}>\\d+) /)
  end

  defp convert_double_quote_strings(step_text) do
    join_dqs_split(Regex.split(@double_quote_regex, step_text), 1, "")
  end

  defp join_dqs_split([], _count, acc), do: String.trim(acc)
  defp join_dqs_split([head | []], count, acc) do
    join_dqs_split([], count + 1, acc <> head)
  end
  defp join_dqs_split([head | tail], count, acc) do
    join_dqs_split(tail, count + 1, acc <> head <> ~s/"(?<string_#{count}>[^"]+)"/)
  end

  defp convert_single_quote_strings(step_text) do
    join_sqs_split(Regex.split(@single_quote_regex, step_text), 1, "")
  end

  defp join_sqs_split([], _count, acc), do: String.trim(acc)
  defp join_sqs_split([head | []], count, acc) do
    join_sqs_split([], count + 1, acc <> head)
  end
  defp join_sqs_split([head | tail], count, acc) do
    join_sqs_split(tail, count + 1, acc <> head <> ~s/'(?<string_#{count}>[^']+)'/)
  end
end
