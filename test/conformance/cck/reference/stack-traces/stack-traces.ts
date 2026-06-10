import { When } from '@cucumber/fake-cucumber'

When('a step throws an exception', () => {
  throw new Error('BOOM')
})
