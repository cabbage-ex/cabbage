Feature: Can have backgrounds
  Each scenario will be execute backgroud steps beforehand

  Background:
    Given a background step "first step" provided
    And a another step "second step" provided

  Scenario: Can create scenario with backgroud steps
    When step provided in scenario
    Then all steps should have been taken into account

  Scenario: Can create another scenario with backgroud steps
    When another step provided in scenario
    Then all steps should have been taken into account