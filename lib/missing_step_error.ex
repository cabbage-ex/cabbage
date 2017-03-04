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

  def join_num_split([], _count, acc), do: String.trim(acc)
  def join_num_split([str1 | []], count, acc) do
    join_num_split([], count + 1, acc <> str1)
  end
  def join_num_split([str1 | tail], count, acc) do
    join_num_split(tail, count + 1, acc <> str1 <> ~s/ (?<number_#{count}>\\d+) /)
  end

  defp convert_double_quote_strings(step_text) do
    Regex.replace(@double_quote_regex, step_text, ~s/"(?<string>[^"]+)"/)
  end

  defp convert_single_quote_strings(step_text) do
    Regex.replace(@single_quote_regex, step_text, ~s/'(?<string>[^']+)'/)
  end
end
