defmodule Cabbage.CucumberExpression.TreeRegexp do
  @moduledoc """
  Wraps a compiled regex and reconstructs the tree of capture groups so that
  each parameter's matched value (and its sub-group values) can be recovered.

  Ported from cucumber/cucumber-expressions (`TreeRegexp` + `GroupBuilder` +
  `Group`). The group tree is derived by scanning the regex source for
  parentheses (skipping escapes and character classes, and marking
  non-capturing groups), then populated from a match's indexed captures.
  """

  alias Cabbage.CucumberExpression.TreeRegexp

  defstruct [:regex, :group_builder]

  @type group :: %{value: String.t() | nil, children: [group()] | nil}

  @doc "Compiles `source` and builds the matching group-builder tree."
  @spec new(String.t()) :: %TreeRegexp{}
  def new(source) do
    %TreeRegexp{
      regex: Regex.compile!(source),
      group_builder: build_group_builder(source)
    }
  end

  @doc """
  Matches `text`. Returns the root `group` (with `:children` = parameter groups)
  or `nil` when there is no match.
  """
  @spec match(%TreeRegexp{}, String.t()) :: group() | nil
  def match(%TreeRegexp{regex: regex, group_builder: gb}, text) do
    case Regex.run(regex, text, return: :index) do
      nil ->
        nil

      indices ->
        # indices: [{start, len}, ...] in capture-group order (0 = full match).
        # Non-participating groups come back as {-1, 0} (or {-1, _}) in Erlang.
        indexed = List.to_tuple(Enum.map(indices, &slice(&1, text)))
        {group, _next} = build_group(gb, indexed, 0)
        group
    end
  end

  @doc """
  Like `match/2`, but each group also carries its `:start` offset (the byte index of
  the captured substring in `text`, or `nil` when the group did not participate).

  Callers that build cucumber-messages `stepMatchArguments` need both the matched value
  and its start position. For ASCII source text the byte offset equals the character
  offset the cucumber-messages goldens expect.
  """
  @spec match_with_index(%TreeRegexp{}, String.t()) :: group() | nil
  def match_with_index(%TreeRegexp{regex: regex, group_builder: gb}, text) do
    case Regex.run(regex, text, return: :index) do
      nil ->
        nil

      indices ->
        indexed = indices |> Enum.map(&located(&1, text)) |> List.to_tuple()
        {group, _next} = build_located_group(gb, indexed, 0)
        group
    end
  end

  defp located({start, _len}, _text) when start < 0, do: %{start: nil, value: nil}
  defp located({start, len}, text), do: %{start: start, value: binary_part(text, start, len)}

  defp build_located_group(builder, indexed, group_index) do
    %{start: start, value: value} = located_or_nil(indexed, group_index)

    {children, next_index} =
      Enum.reduce(builder.children, {[], group_index + 1}, fn child, {acc, idx} ->
        {child_group, new_idx} = build_located_group(child, indexed, idx)
        {[child_group | acc], new_idx}
      end)

    children = Enum.reverse(children)
    group = %{start: start, value: value, children: if(children == [], do: nil, else: children)}
    {group, next_index}
  end

  defp located_or_nil(tuple, idx) when idx < tuple_size(tuple), do: elem(tuple, idx)
  defp located_or_nil(_tuple, _idx), do: %{start: nil, value: nil}

  defp slice({start, _len}, _text) when start < 0, do: nil
  defp slice({start, len}, text), do: binary_part(text, start, len)

  @doc "All capture-group values of a group: its children's values, or its own."
  @spec values(group()) :: [String.t() | nil]
  def values(%{children: nil, value: value}), do: [value]
  def values(%{children: children}), do: Enum.map(children, & &1.value)

  # ---- group tree construction (from match) ----------------------------------

  defp build_group(builder, indexed, group_index) do
    value = elem_or_nil(indexed, group_index)

    {children, next_index} =
      Enum.reduce(builder.children, {[], group_index + 1}, fn child, {acc, idx} ->
        {child_group, new_idx} = build_group(child, indexed, idx)
        {[child_group | acc], new_idx}
      end)

    children = Enum.reverse(children)
    group = %{value: value, children: if(children == [], do: nil, else: children)}
    {group, next_index}
  end

  defp elem_or_nil(tuple, idx) when idx < tuple_size(tuple), do: elem(tuple, idx)
  defp elem_or_nil(_tuple, _idx), do: nil

  # ---- group-builder tree (from regex source) --------------------------------

  defp build_group_builder(source) do
    chars = String.graphemes(source)
    root = %{capturing: true, children: []}

    {[root_built], _start_stack, _escaping, _char_class} =
      do_scan(chars, 0, [root], [], false, false, source)

    root_built
  end

  # Stack holds in-progress group builders (innermost on top). On ')', pop and
  # either attach (capturing) or splice children into parent (non-capturing).
  defp do_scan([], _i, stack, start_stack, escaping, char_class, _source) do
    {stack, start_stack, escaping, char_class}
  end

  defp do_scan([c | rest], i, stack, start_stack, escaping, char_class, source) do
    cond do
      c == "[" and not escaping and not char_class ->
        do_scan(rest, i + 1, stack, start_stack, next_escaping(c, escaping), true, source)

      c == "]" and not escaping and not char_class ->
        # ']' outside a class — treat as literal, no state change.
        do_scan(rest, i + 1, stack, start_stack, next_escaping(c, escaping), char_class, source)

      c == "]" and not escaping and char_class ->
        do_scan(rest, i + 1, stack, start_stack, next_escaping(c, escaping), false, source)

      c == "(" and not escaping and not char_class ->
        gb = %{capturing: not non_capturing?(source, i), children: []}
        do_scan(rest, i + 1, [gb | stack], [i | start_stack], false, char_class, source)

      c == ")" and not escaping and not char_class ->
        [gb | rest_stack] = stack
        [_start | rest_starts] = start_stack
        [parent | grandparents] = rest_stack

        parent =
          if gb.capturing do
            %{parent | children: parent.children ++ [strip_children_keep_self(gb)]}
          else
            %{parent | children: parent.children ++ gb.children}
          end

        do_scan(rest, i + 1, [parent | grandparents], rest_starts, false, char_class, source)

      true ->
        do_scan(rest, i + 1, stack, start_stack, next_escaping(c, escaping), char_class, source)
    end
  end

  defp strip_children_keep_self(gb), do: %{capturing: true, children: gb.children}

  defp next_escaping("\\", escaping), do: not escaping
  defp next_escaping(_c, _escaping), do: false

  # Determine if the group opening at index `i` is non-capturing.
  defp non_capturing?(source, i) do
    c1 = at(source, i + 1)

    cond do
      c1 != "?" -> false
      at(source, i + 2) != "<" -> true
      true -> at(source, i + 3) in ["=", "!"]
    end
  end

  defp at(source, i) when i >= 0 and i < byte_size(source), do: String.at(source, i)
  defp at(_source, _i), do: nil
end
