import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import { applyToSession } from '../engine/scripts/injector.mjs';
test('applying visual styles does not disable the app content security policy',async()=>{
  const context=vm.createContext({});
  const session={send(){throw new Error('Security policy must remain enforced');},evaluate:async expression=>vm.runInContext(expression,context)};
  assert.equal(await applyToSession(session,'2 + 3'),5);
});
