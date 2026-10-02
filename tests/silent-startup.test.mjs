import test from 'node:test';
import assert from 'node:assert/strict';
import { parseArgs, shouldShowOperationUi } from '../engine/scripts/injector.mjs';

test('automatic one-shot retries can run without an in-app status window',()=>{
  const options=parseArgs(['--once','--silent-ui','--browser-id','test-browser']);
  assert.equal(options.silentUi,true);
  assert.equal(shouldShowOperationUi(options),false);
});

test('explicit one-shot operations retain progress feedback',()=>{
  const options=parseArgs(['--once','--browser-id','test-browser']);
  assert.equal(shouldShowOperationUi(options),true);
});
