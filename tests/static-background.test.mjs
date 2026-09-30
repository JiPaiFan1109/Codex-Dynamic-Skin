import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import { makeFixture, fixture } from './support/renderer-fixture.mjs';
import { loadPayload } from '../engine/scripts/injector.mjs';
fixture.template=await fs.readFile(new URL('../engine/assets/renderer-inject.js',import.meta.url),'utf8');
test('an image-only theme displays its own background layer and restores it cleanly',()=>{
  const f=makeFixture();vm.runInNewContext(f.payloadFor(),f.context);
  const state=f.window.__CODEX_DREAM_SKIN_STATE__;
  const image=f.document.getElementById('codex-dream-skin-image');
  assert.ok(image,'static background element must exist');
  assert.equal(image.src,state.artUrl);
  assert.equal(image.getAttribute('aria-hidden'),'true');
  assert.equal(f.document.getElementById('codex-dream-skin-video-frame'),null);
  state.cleanup();
  assert.equal(f.document.getElementById('codex-dream-skin-image'),null);
  assert.ok(f.revoked.includes(state.artUrl));
});
test('switching from video to a static theme removes the video and its Blob',()=>{
  const f=makeFixture();vm.runInNewContext(f.payloadFor({video:{url:'http://127.0.0.1:9335/'+'a'.repeat(64)+'/video.mp4'}}),f.context);
  const old=f.window.__CODEX_DREAM_SKIN_STATE__;old.videoBlobUrl='blob:previous-video';
  vm.runInNewContext(f.payloadFor(),f.context);
  assert.ok(f.document.getElementById('codex-dream-skin-image'));
  assert.equal(f.document.getElementById('codex-dream-skin-video-frame'),null);
  assert.ok(f.revoked.includes('blob:previous-video'));
});
test('shipped default background builds a valid payload without personal paths',async()=>{
  const payload=await loadPayload(fileURLToPath(new URL('../engine/assets',import.meta.url)));
  assert.equal(payload.theme.id,'preset-neutral');
  assert.equal(payload.video,null);
  assert.doesNotMatch(payload.payload,/[A-Z]:[\\/]+Users[\\/]+|arina-hashimoto|桥本有菜/i);
});
