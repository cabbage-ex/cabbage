import fs from 'node:fs'
import { After, Before, When } from '@cucumber/fake-cucumber'

Before({}, async function () {
  await this.attach(fs.createReadStream(`${import.meta.dirname}/cucumber.svg`), 'image/svg+xml')
})

When('a step passes', () => {
  // no-op
})

After({}, async function () {
  await this.attach(fs.createReadStream(`${import.meta.dirname}/cucumber.svg`), 'image/svg+xml')
})
