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


"""

iex(1)> string = "I set my name to \"Dan\" and also \"John\" "
"I set my name to \"Dan\" and also \"John\" "
iex(2)> regex = ~r/"[^"]+"/
~r/"[^"]+"/
iex(3)> Regex.split(regex, string)
["I set my name to ", " and also ", " "]
iex(4)> res = Regex.split(regex, string)
["I set my name to ", " and also ", " "]
iex(5)> Enum.reduce(res, "", fn(x, acc) -> acc <> "\"(?<>)\"" <> x end)
"\"(?<>)\"I set my name to \"(?<>)\" and also \"(?<>)\" "
iex(6)> Regex.split(~r/3425345435/, string)
["I set my name to \"Dan\" and also \"John\" "]
iex(7)> string = "34 hello 45"
"34 hello 45"
iex(8)> regex2 = ~r/(^|\s)\d+(\s|$)/
~r/(^|\s)\d+(\s|$)/
iex(9)> Regex.split(regex2, string)
["", "hello", ""]
iex(10)>




"""

  def exception(step_text: step_text, step_type: step_type) do
    converted_step_text =
      step_text
      |> convert_multiples(&match_numbers?/1, &convert_numbers/2)
      # |> reduce_num_split(&Regex.split(@number_regex, &1), 1)
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

  # defp reduce_num_split([str1 | [str2 | tail]], count) do
  #   reduce_num_split([str1 <> ~s/(?<number_#{count}>\\d+)/ | tail], count + 1)
  # end
  #
  # defp reduce_num_split([str], _count), do: str

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
