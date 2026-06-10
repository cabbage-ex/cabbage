Feature: Skipping scenarios via exception

  Some implementations support marking a step skipped via throwing
  an exception, which can include a message

  Scenario: Skipping via an exception
    Given I skip a step
