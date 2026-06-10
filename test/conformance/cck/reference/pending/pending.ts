import { Given } from '@cucumber/fake-cucumber'

Given('an implemented non-pending step', () => {
  // no-op
})

Given('an implemented step that is skipped', () => {
  // no-op
})

Given('an unimplemented pending step', () => 'pending')
