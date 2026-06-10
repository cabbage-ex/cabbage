Feature: Support standard Cucumber Expressions
  As a developer
  I want cabbage to match steps written as real Cucumber Expressions
  So that anonymous parameters, optional text and alternation work

  Scenario: Anonymous parameter with optional text and alternation
    Given I start with 1 cuke
    When I add 2 cukes
    Then I end with 3 banana
