import assert from 'node:assert'
import { type DataTable, Then, When } from '@cucumber/fake-cucumber'

When('the following table is transposed:', function (table: DataTable) {
  this.transposed = table.transpose()
})

Then('it should be:', function (expected: DataTable) {
  assert.deepStrictEqual(this.transposed.raw(), expected.raw())
})
