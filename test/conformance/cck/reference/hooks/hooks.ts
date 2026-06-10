import { After, Before, When } from '@cucumber/fake-cucumber'

Before({}, () => {
  // no-op
})

When('a step passes', () => {
  // no-op
})

When('a step fails', () => {
  throw new Error('Exception in step')
})

After({}, () => {
  // no-op
})
