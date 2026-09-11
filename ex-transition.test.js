const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const {build} = require('./build-sequence');
for (const skin of [undefined, path.join(__dirname, 'skins', '机甲')]) {
  const bundle = build(skin);
  assert.equal(bundle.manifest.length, 8);
  assert(!bundle.manifest.some(x => /pelican/.test(x.path)));
  assert(!bundle.source.includes('window.pelicanTransition ='));
  assert(!bundle.source.includes('<div class="pelican-transition-overlay"'));
  assert(!bundle.source.includes('pelicanTransition.init()'));
}
const node = () => ({style:{setProperty(){}},dataset:{},classList:{add(){},remove(){}}});
const window = {};
const context = {window,cancelAnimationFrame(){}};
const read = name => fs.readFileSync(path.join(__dirname,'visual-core/src/js',name+'.js'),'utf8');
vm.runInNewContext(read('skin-config'),context);
window.VisualState = {clamp:(v,min=0,max=1)=>Math.max(min,Math.min(max,v)),normalizeLevelIndex:v=>v};
window.previewHost = {nodes:Object.fromEntries(['root','body','skinLayerB','skinTint','ambientLight'].map(k=>[k,node()])),events:{emit(){}},visibility:{isHidden:()=>false,onChange(){}},reducedMotion:{matches:()=>true,onChange(){}}};
let prepared, exited=0;
window.skinEngine = {prepareExTransition:l=>prepared=l,renderExProgress(){},finishExExit:()=>exited++};
vm.runInNewContext(read('ex-motion'),context);
(async()=>{
 for (let level=1;level<=6;level++) {
  assert.equal((await window.exMotion.enter(level)).phase,'ambient');
  assert.equal(prepared,level);
  assert.equal((await window.exMotion.exit()).phase,'mainline');
 }
 assert.equal(exited,6);
 console.log('PASS: both skin bundles omit pelican; all six levels enter and exit EX');
})().catch(e=>{console.error(e);process.exitCode=1;});
