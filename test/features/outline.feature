Feature: Provide outline
  Can create abstract scenario with dynamic values populated from datatable provided seperately

  Scenario Outline: Outlined scenario
    Given there is given <given> value
    When there is when <when> value
    Then there is then <then> value

    Examples:
      | given | when | then |
      | a | b | ab |
      | c | d | cd |
      | e | f | ef |

  Scenario Outline: Outlined scenario with numbers
    Given there is given numeric <given> value
    When there is when numeric <when> value
    Then there is then numeric <then> value

    Examples:
      | given | when | then |
      | 2 | 3 | 5 |
      | 3 | 5 | 8 |
      | 5 | 8 | 13 |