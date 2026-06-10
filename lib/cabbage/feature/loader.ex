defmodule Cabbage.Feature.Loader do
  @moduledoc """
  Loads a `.feature` file into the `Cabbage.Feature.{Document, Scenario, Step}`
  structs the runner compiles into ExUnit tests.

  The heavy lifting is done by `Gherkin.pickles/2`, which returns fully-resolved
  pickles: scenario-outline rows expanded, background (feature- and rule-level)
  steps prepended, tags inherited and unioned, conjunction (`And`/`But`/`*`) step
  types resolved, and `<placeholder>` substitution applied. This module is a thin
  projection from those pickles onto cabbage's runner-internal structs, so the
  runner's step-matching and state-threading are unchanged.
  """

  alias Cabbage.Feature.{Document, Scenario, Step}

  def load_from_file(path) do
    uri = "#{Cabbage.base_path()}#{path}"

    uri
    |> File.read!()
    |> load_from_string(uri)
  end

  def load_from_string(string, uri \\ "") do
    document = Gherkin.parse!(string, uri: uri)
    pickles = Gherkin.pickles(string, uri: uri)

    %Document{
      name: feature_name(document),
      file: nilable_uri(uri),
      scenarios: scenarios(pickles)
    }
  end

  defp feature_name(%Gherkin.AST.GherkinDocument{feature: nil}), do: ""
  defp feature_name(%Gherkin.AST.GherkinDocument{feature: %{name: name}}), do: name

  defp nilable_uri(""), do: nil
  defp nilable_uri(uri), do: uri

  # A pickle's name follows the cucumber-messages spec: a plain scenario keeps its
  # name, and every Examples row of an outline reuses the outline's name. ExUnit needs
  # unique `describe`/test names, so when a name repeats within the feature we suffix
  # the duplicates with ` (Example N)` (numbered per base name, in document order).
  defp scenarios(pickles) do
    counts = Enum.frequencies_by(pickles, & &1.name)

    {scenarios, _seen} =
      Enum.map_reduce(pickles, %{}, fn pickle, seen ->
        seen = Map.update(seen, pickle.name, 1, &(&1 + 1))
        index = Map.fetch!(seen, pickle.name)
        name = disambiguate(pickle.name, index, Map.fetch!(counts, pickle.name))

        scenario = %Scenario{
          name: name,
          line: pickle_line(pickle),
          tags: Enum.map(pickle.tags, &tag_atom/1),
          steps: Enum.map(pickle.steps, &step/1)
        }

        {scenario, seen}
      end)

    scenarios
  end

  defp disambiguate(name, _index, 1), do: name
  defp disambiguate(name, index, _count), do: "#{name} (Example #{index})"

  defp pickle_line(%{location: %{line: line}}), do: line
  defp pickle_line(_), do: 0

  defp step(pickle_step) do
    %Step{
      keyword: keyword(pickle_step.type),
      text: pickle_step.text,
      table_data: table_data(pickle_step.argument),
      doc_string: doc_string(pickle_step.argument)
    }
  end

  # Pickle step types are already conjunction-resolved; map them back to the display
  # keyword the runner logs and uses for missing-step suggestions.
  defp keyword("Context"), do: "Given"
  defp keyword("Action"), do: "When"
  defp keyword("Outcome"), do: "Then"
  defp keyword(_), do: "Given"

  # Legacy table_data shape: a list of maps keyed by the (atomized) header row.
  defp table_data({:data_table, %{rows: [header | body]}}) do
    keys = Enum.map(header, &String.to_atom/1)

    Enum.map(body, fn row ->
      keys |> Enum.zip(row) |> Map.new()
    end)
  end

  defp table_data(_), do: []

  # Legacy doc_string shape: the content with a trailing newline ("" when absent).
  defp doc_string({:doc_string, %{content: content}}), do: content <> "\n"
  defp doc_string(_), do: ""

  defp tag_atom(%{name: "@" <> name}), do: String.to_atom(name)
  defp tag_atom(%{name: name}), do: String.to_atom(name)
end
