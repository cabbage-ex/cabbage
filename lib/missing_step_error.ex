defmodule MissingStepError do
  @moduledoc """
  Raises an error, because a feature step is missing its implementation.

  The message of the error will give the user a useful code snippet where
  variables in feature steps are converted to regex capture groups.
  """

  defexception [:message]

  def exception(step_text: step_text, step_type: step_type) do
    converted_step_text =
      step_text
      |> convert_numbers()
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
