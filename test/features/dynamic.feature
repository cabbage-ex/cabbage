Feature: Can have complex features
  Test that can have advanced regular expression line matches and datatables

  Scenario: Can create scenario with dynamic key ingredients
    Given I provide Given with 'given dynamic' part
    When I provide When with "when dynamic" part and with one more "another when dynamic" part
    Then I provide Then with number 6 part and with docs part
      """
      Here is provided some complex part that is way to complex
      """
    And I provide And with "and dynamic" part and with one more "another and dynamic" part and with table part
      | Name | Age |
      | John | 30 |
      | Ann | 29 |