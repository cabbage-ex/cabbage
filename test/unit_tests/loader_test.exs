defmodule Cabbage.Feature.LoaderTest do
  use ExUnit.Case, async: true

  alias Cabbage.Feature.Loader
  alias Cabbage.Feature.{Document, Scenario, Step}

  defp scenarios(feature_string) do
    feature_string
    |> Loader.load_from_string()
    |> Map.fetch!(:scenarios)
  end

  defp keywords(feature_string) do
    feature_string
    |> scenarios()
    |> hd()
    |> Map.fetch!(:steps)
    |> Enum.map(& &1.keyword)
  end

  describe "load_from_string/1" do
    test "returns a Cabbage.Feature.Document projected from pickles" do
      feature = """
      Feature: Coffee
        Scenario: Buy
          Given a precondition
      """

      assert %Document{name: "Coffee", scenarios: [%Scenario{name: "Buy"} = scenario]} =
               Loader.load_from_string(feature)

      assert [%Step{keyword: "Given", text: "a precondition"}] = scenario.steps
    end
  end

  describe "step keyword resolution (via pickle types)" do
    test "rewrites And to the previous step's keyword" do
      feature = """
      Feature: And handling
        Scenario: uses and
          Given a precondition
          And another precondition
          When something happens
          And something else happens
          Then a result occurs
          And another result occurs
      """

      assert keywords(feature) == ~w(Given Given When When Then Then)
    end

    test "rewrites But to the previous step's keyword" do
      feature = """
      Feature: But handling
        Scenario: uses but
          Given a precondition
          But not this precondition
          When something happens
          But not that thing
          Then a result occurs
          But not that result
      """

      assert keywords(feature) == ~w(Given Given When When Then Then)
    end

    test "chains And and But together inheriting the running keyword" do
      feature = """
      Feature: And/But chaining
        Scenario: mixes and and but
          Given a precondition
          And another precondition
          But not this one
          When something happens
          Then a result occurs
      """

      assert keywords(feature) == ~w(Given Given Given When Then)
    end
  end

  describe "background steps (cabbage-ex/cabbage#68)" do
    test "prepends background steps to every scenario" do
      feature = """
      Feature: With background
        Background:
          Given the system is up
          And a user exists

        Scenario: First
          When the user logs in
          Then they see the dashboard

        Scenario: Second
          Then they see a banner
      """

      [first, second] = scenarios(feature)

      assert Enum.map(first.steps, &{&1.keyword, &1.text}) == [
               {"Given", "the system is up"},
               {"Given", "a user exists"},
               {"When", "the user logs in"},
               {"Then", "they see the dashboard"}
             ]

      assert Enum.map(second.steps, &{&1.keyword, &1.text}) == [
               {"Given", "the system is up"},
               {"Given", "a user exists"},
               {"Then", "they see a banner"}
             ]
    end
  end

  describe "rule (cabbage-ex/cabbage#69)" do
    test "expands scenarios under a rule, applying the rule-level background" do
      feature = """
      Feature: With rules
        Background:
          Given the feature background ran

        Rule: A rule
          Background:
            Given the rule background ran

          Scenario: Under the rule
            When something happens
            Then it works
      """

      [scenario] = scenarios(feature)
      assert scenario.name == "Under the rule"

      assert Enum.map(scenario.steps, &{&1.keyword, &1.text}) == [
               {"Given", "the feature background ran"},
               {"Given", "the rule background ran"},
               {"When", "something happens"},
               {"Then", "it works"}
             ]
    end
  end

  describe "scenario outline expansion" do
    test "expands one scenario per examples row and disambiguates duplicate names" do
      feature = """
      Feature: Outlined
        Scenario Outline: Buy <count>
          Given there are <count> left

          Examples:
            | count |
            | 1     |
            | 2     |
      """

      assert [%Scenario{name: "Buy 1"}, %Scenario{name: "Buy 2"}] = scenarios(feature)
    end

    test "numbers same-named outline rows as (Example N) to keep names unique" do
      feature = """
      Feature: Outlined
        Scenario Outline: Outlined scenario
          Given there is <given> value

          Examples:
            | given |
            | a     |
            | b     |
      """

      assert ["Outlined scenario (Example 1)", "Outlined scenario (Example 2)"] =
               feature |> scenarios() |> Enum.map(& &1.name)
    end
  end

  describe "step arguments" do
    test "projects a data table into a list of header-keyed maps" do
      feature = """
      Feature: Tables
        Scenario: With a table
          Given these people
            | Name | Age |
            | John | 30  |
            | Ann  | 29  |
      """

      [scenario] = scenarios(feature)
      [step] = scenario.steps
      assert step.table_data == [%{Name: "John", Age: "30"}, %{Name: "Ann", Age: "29"}]
      assert step.doc_string == ""
    end

    test "projects a doc string into its content with a trailing newline" do
      feature = """
      Feature: Docs
        Scenario: With a doc string
          Given some docs
            \"\"\"
            line one
            line two
            \"\"\"
      """

      [scenario] = scenarios(feature)
      [step] = scenario.steps
      assert step.doc_string == "line one\nline two\n"
      assert step.table_data == []
    end
  end

  describe "tags" do
    test "projects pickle tags into atoms (leading @ stripped)" do
      feature = """
      Feature: Tagged
        @smoke @wip
        Scenario: A
          Given a step
      """

      [scenario] = scenarios(feature)
      assert scenario.tags == [:smoke, :wip]
    end

    test "inherits feature-level tags onto each scenario" do
      feature = """
      @feature_tag
      Feature: Tagged
        @scenario_tag
        Scenario: A
          Given a step
      """

      [scenario] = scenarios(feature)
      assert :feature_tag in scenario.tags
      assert :scenario_tag in scenario.tags
    end
  end
end
