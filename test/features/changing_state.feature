Feature: Changing state
  Users can change state

  Scenario: No state change
    Given a start state
    Then the state is not changed

  Scenario: State change
    Given a start state
    When I change the state
    Then the state is changed
