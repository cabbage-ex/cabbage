import { AfterAll, BeforeAll, When } from '@cucumber/fake-cucumber'

BeforeAll({}, () => {
  // no-op
})

BeforeAll({}, () => {
  // no-op
})

When('a step passes', () => {
  // no-op
})

When('a step fails', () => {
  throw new Error('Exception in step')
})

AfterAll({}, () => {
  // no-op
})

AfterAll({}, () => {
  // no-op
})
