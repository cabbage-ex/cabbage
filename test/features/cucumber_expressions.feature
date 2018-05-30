Feature: Support cucumber expressions
  As a developer
  I want to support Cucumber Expressions
  So I can specify data type inside a step definition

  Scenario: Cucumber Expression as first parameter in step definitions
    Given Step definition using 1 int
    And 1.0 float
    And one word
    And "one simple" string
    When I check type of named captures
    Then Named captures are of expected type