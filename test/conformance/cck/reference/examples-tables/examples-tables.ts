import assert from 'node:assert'
import { Given, Then, When } from '@cucumber/fake-cucumber'

Given('there are {int} cucumbers', function (initialCount) {
  this.count = initialCount
})

Given('there are {int} friends', function (initialFriends) {
  this.friends = initialFriends
})

When('I eat {int} cucumbers', function (eatCount) {
  this.count -= eatCount
})

Then('I should have {int} cucumbers', function (expectedCount) {
  assert.strictEqual(this.count, expectedCount)
})

Then('each person can eat {int} cucumbers', function (expectedShare) {
  const share = Math.floor(this.count / (1 + this.friends))
  assert.strictEqual(share, expectedShare)
})
