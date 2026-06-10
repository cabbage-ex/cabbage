Feature: Skipped followed by failing hook

  Failure in an After hook following a skipped step will cause that test case to be considered failed
  overall.

  Scenario: Failure in an After hook
    Given a step that skips
