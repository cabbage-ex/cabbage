Feature: Serve coffee
  Coffee should not be served until paid for
  Coffee should not be served until the button has been pressed
  If there is no coffee left then money should be refunded

  Scenario Outline: Buy coffee
    Given there are <coffees> coffees left in the machine
    And I have deposited $<money>
    When I press the coffee button
    Then I should be served <served> coffees

  Examples:
    | coffees | money | served |
    |  12     |  6    |  12    |
    |  2      |  3    |  2     |
    |  0      |  10   |  0     |
