Feature: Pending steps via exception
  Some implementations support marking a step pending via throwing
  an exception, which can include a message

  Scenario: Pending via an exception
    Given an unimplemented pending step
