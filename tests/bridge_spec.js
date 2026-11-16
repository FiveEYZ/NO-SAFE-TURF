'use strict';
const assert=require('node:assert/strict');
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const {createBridge}=require('../resource/server/storage/bridge');
async function main(){
  let starts=0,closed=0,mode='ok';
  const store={initialize:async()=>{starts++;},state:async()=>({revision:1}),close:async()=>{closed++;},
    commit:async()=>{if(mode!=='ok')throw Object.assign(new Error('PRIVATE SECRET SQL'),{code:mode});return {revision:2};},wipe:async(key,dryRun)=>({key,dryRun})};
  const bridge=createBridge(store);
  assert.deepEqual((await Promise.all([bridge.request('/state'),bridge.request('/state')])).map(x=>x.code),[200,200]);
  assert.equal(starts,1);
  assert.equal((await bridge.request('/commit','POST','{')).code,400);
  assert.equal((await bridge.request('/bad')).code,404);
  assert.equal((await bridge.request('/state','GET','x'.repeat(4500001))).code,413);
  for(const [error,code] of [['CONFLICT',409],['VALIDATION',400],['ER_ACCESS_DENIED_ERROR',503]]){
    mode=error;const result=await bridge.request('/commit','POST','{}');assert.equal(result.code,code);assert(!JSON.stringify(result).includes('PRIVATE'));
  }
  assert.equal((await bridge.request('/wipe','POST','{"key":"test","dryRun":true}')).data.dryRun,true);
  await bridge.stop();assert.equal(closed,1);assert.equal((await bridge.request('/state')).code,503);
  let attempts=0;
  const retry=createBridge({...store,initialize:async()=>{if(++attempts===1)throw new Error('offline');}});
  assert.equal((await retry.request('/state')).code,503);assert.equal((await retry.request('/state')).code,200);await retry.stop();
  const root=path.resolve(__dirname,'../resource');let exported,stop,command,scheduled=0;
  const context={require:name=>{
    if(name.endsWith('mysql2/promise'))return {createPool:()=>({})};
    if(name.endsWith('config.js'))return {readConfig:()=>({}),safeError:()=> 'Storage unavailable'};
    if(name.endsWith('store.js'))return {MariaDBStore:class{}};
    if(name.endsWith('bridge.js'))return {createBridge:()=>({request:async()=>({code:200,data:{revision:7}}),ready:async()=>{},stop:async()=>{}})};
    return require(name);
  },GetCurrentResourceName:()=> 'no_safe_turf',GetResourcePath:()=>root,GetConvar:(_,d)=>d,GetConvarInt:(_,d)=>d,
  exports:(name,fn)=>{assert.equal(name,'storageRequest');exported=fn;},RegisterCommand:(_,fn)=>{command=fn;},on:(_,fn)=>{stop=fn;},console,
  setImmediate:fn=>{scheduled++;setImmediate(fn);}};
  vm.runInNewContext(fs.readFileSync(path.join(root,'server/storage.js'),'utf8'),context);
  const reply=await new Promise(resolve=>exported('/state','GET','',(code,body)=>resolve({code,body})));
  assert.equal(reply.code,200);assert.equal(JSON.parse(reply.body).revision,7);assert.equal(scheduled,1);command(1);stop('another_resource');
  console.log('PASS: storage bridge validation, concurrent startup, retry, sanitized failures, shutdown and mocked FiveM callback');
}
main().catch(error=>{console.error(error);process.exitCode=1;});
