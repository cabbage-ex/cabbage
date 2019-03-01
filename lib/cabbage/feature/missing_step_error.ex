defmodule Cabbage.Feature.MissingStepError do
  @moduledoc """
  Raises an error, because a feature step is missing its implementation.

  The message of the error will give the user a useful code snippet where
  variables in feature steps are converted to regex capture groups.
  """

  defexception [:message]

  @number_regex ~r/(^|\s)\d+(\s|$)/
  @single_quote_regex ~r/'[^']+'/
  @double_quote_regex ~r/"[^"]+"/

  def exception(step_text: step_text, step_type: step_type, extra_vars: extra_vars) do
    {converted_step_text, list_of_vars} =
      {step_text, []}
      |> convert_nums()
      |> convert_double_quote_strings()
      |> convert_single_quote_strings()
      |> convert_extra_vars(extra_vars)

    map_of_vars = vars_to_correct_format(list_of_vars)

    message = """
    Please add a matching step for:
    "#{step_type} #{step_text}"

      def#{step_type |> String.downcase()} ~r/^#{converted_step_text}$/, #{map_of_vars}, state do
        # Your implementation here
      end
    """

    %__MODULE__{message: message}
  end

  defp convert_nums({step_text, vars}) do
    @number_regex
    |> Regex.split(step_text)
    |> join_regex_split(1, :number, {"", vars})
  end

  defp convert_double_quote_strings({step_text, vars}) do
    @double_quote_regex
    |> Regex.split(step_text)
    |> join_regex_split(1, :double_quote_string, {"", vars})
  end

  defp convert_single_quote_strings({step_text, vars}) do
    @single_quote_regex
    |> Regex.split(step_text)
    |> join_regex_split(1, :single_quote_string, {"", vars})
  end

  defp convert_extra_vars({step_text, vars}, %{doc_string: doc_string, table: table}) do
    vars = if doc_string == "", do: vars, else: vars ++ ["doc_string"]
    vars = if table == [], do: vars, else: vars ++ ["table"]

    {step_text, vars}
  end

  defp join_regex_split([], _count, _type, {acc, vars}) do
    {String.trim(acc), vars}
  end

  defp join_regex_split([head | []], _count, _type, {acc, vars}) do
    {String.trim(acc <> head), vars}
  end

  defp join_regex_split([head | tail], count, type, {acc, vars}) do
    step_text = acc <> head <> get_regex_capture_string(type, count)
    vars = vars ++ [get_var_string(type, count)]

    join_regex_split(tail, count + 1, type, {step_text, vars})
  end

  defp get_regex_capture_string(:number, count), do: ~s/ (?<number_#{count}>\d+) /
  defp get_regex_capture_string(:single_quote_string, count), do: ~s/'(?<string_#{count}>[^']+)'/
  defp get_regex_capture_string(:double_quote_string, count), do: ~s/"(?<string_#{count}>[^"]+)"/

  defp get_var_string(:number, count), do: "number_#{count}"
  defp get_var_string(:single_quote_string, count), do: "string_#{count}"
  defp get_var_string(:double_quote_string, count), do: "string_#{count}"

  defp vars_to_correct_format([]), do: "_vars"

  defp vars_to_correct_format(vars) do
    joined_vars =
      vars
      |> Enum.map(fn var -> "#{var}: #{var}" end)
      |> Enum.join(", ")

    "%{#{joined_vars}}"
  end
end
