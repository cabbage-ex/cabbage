Feature: Users have names
  Users names can be changed

  Scenario: Users can change their name
    Given I am a User
    And I set my name to "Jayne"
    When I set my name to "Mal"
    Then my name is "Mal"
