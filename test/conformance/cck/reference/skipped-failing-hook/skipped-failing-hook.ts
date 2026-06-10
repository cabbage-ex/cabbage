import { After, Given } from '@cucumber/fake-cucumber'

Given('a step that skips', () => 'skipped')

After({}, () => {
  throw new Error('whoops')
})
