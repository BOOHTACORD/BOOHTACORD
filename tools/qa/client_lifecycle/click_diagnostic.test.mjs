import assert from 'node:assert/strict'
import { test } from 'node:test'
import { clickFailureStage } from './click_diagnostic.mjs'

test('maps click failures to a finite category without exposing message contents', () => {
  for (const [message, expected] of [
    ['private: intercepts pointer events', 'settings-cancel-pointer-blocked'],
    ['private: element is not enabled', 'settings-cancel-disabled'],
    ['private: strict mode violation', 'settings-cancel-ambiguous'],
    ['private: element is outside of the viewport', 'settings-cancel-outside'],
    ['private', 'settings-cancel-other'],
  ]) assert.equal(clickFailureStage(new Error(message)), expected)
})
