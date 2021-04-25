Feature: Rule feature works
  Tests that multiple Rules work with backgrounds of all kinds.

  Background:
    Given I provide Background

  Rule: First rule has no additional background

    Scenario: Background provides default state
      Then I provided Background

  Rule: Second rule provides additional background

    Background:
      Given I provide additional Background

    Scenario: Background provides default state again
      Then I provided Background
      And I provided additional Background