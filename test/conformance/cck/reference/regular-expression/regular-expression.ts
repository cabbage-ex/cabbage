import { Given } from '@cucumber/fake-cucumber'

Given(
  /^a (.*?)(?: and a (.*?))?(?: and a (.*?))?$/,
  (_vegetable1: string, _vegetable2: string, _vegetable3: string) => {
    // no-op
  }
)
