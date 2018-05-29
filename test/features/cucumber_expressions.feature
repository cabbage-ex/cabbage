Feature: Support cucumber expressions
  As a developer
  I want to support Cucumber Expressions
  So I can specify data type inside a step definition

  Scenario: Cucumber Expression in step definition
    Given Step definition using string as first parameter
    When I run the test file
    Then I should see it passing