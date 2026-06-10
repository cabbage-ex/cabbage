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

AfterAll({}, () => {
  // no-op
})

AfterAll({}, () => {
  throw new Error('AfterAll hook went wrong')
})

AfterAll({}, () => {
  // no-op
})
