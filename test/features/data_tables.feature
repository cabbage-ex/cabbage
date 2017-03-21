@wip
Feature: Data Tables
  As a developer
  I want support for Data Tables
  So I can get a list of values inside a step definition

Scenario: Data table represented as a list of maps
  Given the following data table
  | id  | name  |
  | 1   | Luke  |
  | 2   | Darth |
  When I run a the test file
  Then in the step definition I should get a var with the value
  """
  [%{id: "1", name: "Luke"}, %{id: "2", name: "Darth"}]
  """
