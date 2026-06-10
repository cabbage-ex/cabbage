import { Given, PendingException } from '@cucumber/fake-cucumber'

Given('an unimplemented pending step', () => {
  throw new PendingException('TODO')
})
