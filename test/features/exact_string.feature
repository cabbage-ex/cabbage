Feature: Exact string step matching

  Scenario: Literal step text with regex metacharacters
    Given It costs $5 (USD)
    When I add 1 + 1 = 2
    Then the result is a.b.c
