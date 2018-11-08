Feature: Tag Scenario
  As a Product Manager/Developer
  I want to add tags to a scenario in a feature file
  So I can do stuff with the steps implementation based on tags

  @wip
  Scenario: Run test for a scenario tagged as @wip
    Given a scenario is tagged as "@wip"
    When run mix test --only wip some_test.exs
    Then this test should be marked with "@wip" tag

  @skip
  Scenario: Skipping tests
    Given a scenario is tagged as "@skip"
    When run mix test
    Then this test should be skipped and never run

  @timeout 1000
  Scenario: Chanage the timeout value
    Given a scenario is tagged as "@timeout"
    When it takes longer than the timeout
    Then the test fails

  Scenario: Run test for a scenario tagged as @global_integration_test
    Given global tag is set to "@global_integration_test"
    When run mix test --only "@global_integration_test" some_test.exs
    Then this test should be marked with "@global_integration_test" tag
