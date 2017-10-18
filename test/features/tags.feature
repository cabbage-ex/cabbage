Feature: Tag Scenario
  As a Product Manager/Developer
  I want to add tags to a scenario in a feature file
  So I can do stuff with the steps implementation based on tags

@wip
Scenario: Run test for a scenario tagged as @wip
  Given a scenario is tagged as "@wip"
  When run mix test --only wip some_test.exs
  Then this test should be marked with that tag

@skip
Scenario: Skipping tests
  Given a scenario is tagged as "@skip"
  When run mix test
  Then this test should be skipped and never run
