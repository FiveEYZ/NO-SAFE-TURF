'use strict';
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
async function scenario({running=false,denied=false,journal=null}={}){
 const tasks=[],events={},logs=[];let started=0,cancelled=0;
 const fakeFs={readFileSync(){if(denied)throw Object.assign(new Error('Permission denied'),{code:'EACCES'});if(journal!==null)return journal;throw Object.assign(new Error('Missing'),{code:'ENOENT'});}};
 const context={Buffer,URL,console:{log:s=>logs.push(s)},require:name=>name==='node:fs'?fakeFs:name.endsWith('engine.js')?{createEngine:()=>({recover(){if(denied)throw new Error('Permission denied');}})}:require(name),GetCurrentResourceName:()=> 'nst_updater',GetResourcePath:n=>'/resources/'+n,on:(n,fn)=>events[n]=fn,RegisterCommand:()=>{},GetResourceState:()=>running?'started':'stopped',GetNumPlayerIndices:()=>0,GetConvarInt:()=>0,CancelEvent:()=>cancelled++,StartResource:()=>{started++;return true;},setImmediate:fn=>tasks.push(fn),setTimeout,clearTimeout};
 vm.runInNewContext(fs.readFileSync('updater/server.js','utf8'),context);
 events.onResourceStarting('no_safe_turf');assert.equal(cancelled,1);
 while(tasks.length){await tasks.shift()();await Promise.resolve();}
 const before=cancelled;events.onResourceStarting('no_safe_turf');
 return {started,held:cancelled>before,logs};
}
(async()=>{
 let r=await scenario();assert.equal(r.started,1);assert.equal(r.held,false);
 r=await scenario({running:true});assert.equal(r.started,0);assert.equal(r.held,false);
 r=await scenario({denied:true});assert.equal(r.started,0);assert.equal(r.held,true);
 r=await scenario({running:true,journal:'{}'});assert.equal(r.started,0);assert.equal(r.held,true);
 console.log('PASS: updater startup gate, disabled mode, live restart and unreadable recovery fail closed');
})().catch(e=>{console.error(e);process.exitCode=1;});
