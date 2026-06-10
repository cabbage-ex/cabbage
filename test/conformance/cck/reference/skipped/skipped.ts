import { Given } from '@cucumber/fake-cucumber'

Given('a step that does not skip', () => {
  // no-op
})

Given('a step that is skipped', () => {
  // no-op
})

Given('I skip a step', () => 'skipped')
