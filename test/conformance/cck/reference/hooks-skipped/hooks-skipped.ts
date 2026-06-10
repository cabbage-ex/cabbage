import { After, Before, Given } from '@cucumber/fake-cucumber'

Before({}, () => {
  // no-op
})

Before({ tags: '@skip-before' }, () => 'skipped')

Before({}, () => {
  // no-op
})

Given('a normal step', () => {
  // no-op
})

Given('a step that skips', () => 'skipped')

After({}, () => {
  // no-op
})

After({ tags: '@skip-after' }, () => 'skipped')

After({}, () => {
  // no-op
})
