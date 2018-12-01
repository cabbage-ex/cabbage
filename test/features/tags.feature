Feature: Can have tagged features
  Tests apply provided tags (in feature files, in test files and globally from config)

  Scenario: Not tagged scenario
    When I provide When
    Then I provide Then

  @some_tag
  Scenario: Scenario with single tag
    When I provide When
    Then I provide Then

  @some_tag @another_tag
  Scenario: Scenario with many tags
    When I provide When
    Then I provide Then

  @tag_with_value my_value
  Scenario: Scenario with value for tag
    When I provide When
    Then I provide Then
