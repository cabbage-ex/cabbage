Feature: Failed-ish combinations
  Sometimes the first failed-ish (not passed or skipped) step's status
  is not the only one.

  Rule: Undefined and ambiguous steps can follow a failed-ish step

    Scenario: Pending as the first failed-ish step
      Given a pending step
      And an undefined step
      And an ambiguous step

    Scenario: Undefined as the first failed-ish step
      Given an undefined step
      And an undefined step
      And an ambiguous step

    Scenario: Ambiguous as the first failed-ish step
      Given an ambiguous step
      And an undefined step
      And an ambiguous step

    Scenario: Failed as the first failed-ish step
      Given a failing step
      And an undefined step
      And an ambiguous step

  Rule: Failed and pending steps do not follow a failed-ish step

    Scenario: Pending as the first failed-ish step
      Given a pending step
      And a pending step
      And a failing step

    Scenario: Undefined as the first failed-ish step
      Given an undefined step
      And a pending step
      And a failing step

    Scenario: Ambiguous as the first failed-ish step
      Given an ambiguous step
      And a pending step
      And a failing step

    Scenario: Failed as the first failed-ish step
      Given a failing step
      And a pending step
      And a failing step

  Rule: No pickle steps follow a skipped step

    Scenario: Step marks itself skipped
      Given a skipped step
      And an undefined step
      And an ambiguous step
