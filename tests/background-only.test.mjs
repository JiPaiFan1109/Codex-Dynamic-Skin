import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import vm from 'node:vm';
import { makeFixture, fixture } from './support/renderer-fixture.mjs';
import { parseArgs } from '../engine/scripts/injector.mjs';
fixture.template=await fs.readFile(new URL('../engine/assets/renderer-inject.js',import.meta.url),'utf8');

test('background renderer preserves native theme variables and skips unused artwork analysis',()=>{
  const f=makeFixture();
  f.rootStyle.setProperty('--ds-theme-font-family','native-font');
  let imageAnalysisStarts=0;
  f.context.Image=class { constructor(){imageAnalysisStarts++;} };
  vm.runInNewContext(f.payloadFor(),f.context);
  assert.equal(f.rootStyle.getPropertyValue('--ds-theme-font-family'),'native-font');
  assert.equal(imageAnalysisStarts,0);
  assert.ok(f.document.getElementById('codex-dream-skin-image'));
  f.window.__CODEX_DREAM_SKIN_STATE__.cleanup();
  assert.equal(f.rootStyle.getPropertyValue('--ds-theme-font-family'),'native-font');
});

test('unused upstream operation endpoints are no longer accepted',()=>{
  assert.throws(()=>parseArgs(['--begin-operation','--operation-kind','apply','--browser-id','fixture']),/Unknown argument/);
});
