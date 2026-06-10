import { Given } from '@cucumber/fake-cucumber'

Given(/^a step$/, () => {
  // no-op
})

Given(/^a skipped step$/, () => {
  return 'skipped'
})

Given(/^a pending step$/, () => {
  return 'pending'
})

Given(/^an ambiguous (.*?)$/, () => {})

Given(/^(.*?) ambiguous step$/, () => {})

Given(/^a failing step$/, () => {
  throw new Error('whoops')
})
