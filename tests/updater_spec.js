'use strict';
const assert=require('node:assert/strict');
const {hash,validate,createEngine,newer}=require('../updater/engine');
const file=(path,text)=>({path,content:Buffer.from(text).toString('base64'),sha256:hash(Buffer.from(text))});
const old={format:1,compatibility:1,version:'0.4.0',files:[file('fxmanifest.lua',"version '0.4.0'"),file('server/main.lua','old')]};
const next={...old,version:'0.4.1',files:[file('fxmanifest.lua',"version '0.4.1'"),file('server/main.lua','new')]};
function fixture(){
 const disk=new Map(old.files.map(f=>[f.path,Buffer.from(f.content,'base64')]));
 disk.set('update-state.json',Buffer.from(JSON.stringify({...old,files:old.files.map(({path,sha256})=>({path,sha256}))})));
 disk.set('shared/config.lua',Buffer.from('custom configuration'));
 let journal=null,fail=false,failRollback=false;
 const io={read:p=>disk.get(p)||null,write:(p,data)=>{if((fail&&p==='server/main.lua')||failRollback){fail=false;throw new Error('disk failure');}disk.set(p,data);},remove:p=>disk.delete(p),saveJournal:j=>{journal=structuredClone(j);},readJournal:()=>journal,clearJournal:()=>{journal=null;}};
 return {disk,io,engine:createEngine(io),failure:()=>{fail=true;},rollbackFailure:()=>{failRollback=true;},heal:()=>{failRollback=false;}};
}
assert(newer('0.4.10','0.4.9'));assert(!newer('0.4.0','0.4.0'));assert(!newer('0.3.9','0.4.0'));
for(const p of ['../server.cfg','server/mariadb.private.json','shared/config.lua','web/../../server.cfg','C:\\secret','server-backups/data.json'])assert.throws(()=>validate({...next,files:[file(p,'bad')]}));
assert.throws(()=>validate({...next,files:[...next.files,next.files[0]]}));
assert.throws(()=>validate({...next,files:[{...next.files[0],sha256:'0'.repeat(64)},next.files[1]]}));
let f=fixture();assert(f.engine.apply(next));assert.equal(f.disk.get('server/main.lua').toString(),'new');assert.equal(f.disk.get('shared/config.lua').toString(),'custom configuration');assert.equal(f.io.readJournal(),null);assert(!f.engine.apply(next));
f=fixture();f.disk.set('server/main.lua',Buffer.from('local edit'));assert.throws(()=>f.engine.apply(next),/modified/);assert.equal(f.io.readJournal(),null);
f=fixture();assert.throws(()=>f.engine.apply({...next,files:[...next.files,file('server/new.lua','new')]}),/manual/);
f=fixture();f.failure();assert.throws(()=>f.engine.apply(next),/disk/);assert.equal(f.disk.get('server/main.lua').toString(),'old');assert.equal(f.disk.get('fxmanifest.lua').toString(),"version '0.4.0'");assert.equal(f.io.readJournal(),null);
f=fixture();f.rollbackFailure();assert.throws(()=>f.engine.apply(next));assert(f.io.readJournal());f.heal();f.engine.recover();assert.equal(f.io.readJournal(),null);assert.equal(f.disk.get('server/main.lua').toString(),'old');
console.log('PASS: updater hashes, path restrictions, custom config, local edits, no downgrade, rollback and interrupted recovery');
