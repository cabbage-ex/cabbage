import { Given, SkippedException } from '@cucumber/fake-cucumber'

Given('I skip a step', () => {
  throw new SkippedException('skipping')
})
