Feature: Cucumber Expression typed arguments

  Scenario: Typed parameters arrive transformed and positional
    Given I have 42 cucumbers
    When I add 3.5 kilograms
    Then I eat the "green" one
