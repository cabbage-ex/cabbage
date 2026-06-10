Feature: Scenario can have custom timeout
  Each scenario can provide custom timeout limit

  @slow
  Scenario: Long execution scenario
    When scenario is longer than usual
    Then it still should be executable
