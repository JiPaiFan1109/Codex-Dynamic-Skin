import test from 'node:test';
import assert from 'node:assert/strict';
import vm from 'node:vm';
import fs from 'node:fs/promises';
import { verifySession } from '../engine/scripts/injector.mjs';
const version=(await fs.readFile(new URL('../engine/VERSION',import.meta.url),'utf8')).trim();
function fixture(hasVisibleShell,imageReady=true){
  const node=(width,height)=>({isConnected:true,getBoundingClientRect:()=>({x:0,y:0,width,height,right:width,bottom:height}),querySelectorAll:()=>[]});
  const hidden=node(0,0),visible=node(800,600),sidebar=node(250,600),composer=node(700,90),sheet={};
  const image={isConnected:true,complete:imageReady,naturalWidth:imageReady?1280:0};
  const select=selector=>{
    if(selector.startsWith('main:is')||selector==='[data-ds-part="main"], [data-ds-part="home"]')return hasVisibleShell?[hidden,visible]:[hidden];
    if(selector.startsWith('aside.app-shell'))return[sidebar];
    if(selector.startsWith(':is(.composer-surface')||selector==='[data-ds-part="composer"]')return[composer];
    return[];
  };
  const context=vm.createContext({
    innerWidth:1163,innerHeight:698,
    getComputedStyle:()=>({display:'flex',visibility:'visible',contentVisibility:'visible',opacity:'1',color:'white'}),
    document:{querySelector:s=>select(s)[0]??null,querySelectorAll:select,getElementById:id=>id==='codex-dream-skin-image'?image:null,adoptedStyleSheets:[sheet],visibilityState:'visible',hidden:false,documentElement:{getAttribute:()=> 'active',scrollWidth:1163,clientWidth:1163,scrollHeight:698,clientHeight:698}},
    window:{__CODEX_DREAM_SKIN_STATE__:{version,imageLayer:image,styleMode:'adopted',styleSheet:sheet,scope:{level:'L1',baseState:'thread',missingL1:[]}}}
  });
  return {send:async()=>{throw Object.assign(Error('not supported'),{cdpCode:-32601});},evaluate:async expression=>vm.runInContext(expression,context)};
}
test('visible app shell verifies even when a retained hidden shell comes first',async()=>{
  const result=await verifySession(fixture(true),'test-target');
  assert.equal(result.readiness.structurePass,true);
  assert.equal(result.pass,true);
});
test('only-hidden shell still fails verification',async()=>{
  const result=await verifySession(fixture(false),'test-target');
  assert.equal(result.readiness.structurePass,false);
  assert.equal(result.pass,false);
});
test('a static image that has not decoded must not be reported as applied',async()=>{
  const result=await verifySession(fixture(true,false),'test-target');
  assert.equal(result.pass,false);
});
