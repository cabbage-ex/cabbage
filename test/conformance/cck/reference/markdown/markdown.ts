import assert from 'node:assert'
import { Given, Then, When } from '@cucumber/fake-cucumber'

Given('some TypeScript code:', (dataTable: string[][]) => {
  assert(dataTable)
})

Given('some classic Gherkin:', (gherkin: string) => {
  assert(gherkin)
})

When(
  'we use a data table and attach something and then {word}',
  async function (word: string, dataTable: string[][]) {
    assert(dataTable)
    await this.log(`We are logging some plain text (${word})`)
    if (word === 'fail') {
      throw new Error('You asked me to fail')
    }
  }
)

Then('this might or might not run', () => {
  // no-op
})
