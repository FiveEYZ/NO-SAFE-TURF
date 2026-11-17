'use strict';
const crypto=require('node:crypto');
const hash=data=>crypto.createHash('sha256').update(data).digest('hex');
function check(ok,message){if(!ok)throw new Error(message);}
const allowed=p=>typeof p==='string' && !p.includes('..') && !p.includes('\\') &&
 /^(fxmanifest\.lua|(?:client|server|shared)\/[a-zA-Z0-9_/-]+\.(?:lua|js)|web\/[a-zA-Z0-9_/-]+\.(?:html|css|js))$/.test(p) && p!=='shared/config.lua';
function version(v){check(typeof v==='string'&&/^\d+\.\d+\.\d+$/.test(v),'Invalid version');return v.split('.').map(Number);}
function newer(a,b){const x=version(a),y=version(b);for(let i=0;i<3;i++){if(x[i]!==y[i])return x[i]>y[i];}return false;}
function validate(bundle){
 check(bundle?.format===1&&bundle.compatibility===1,'Update requires manual installation');version(bundle.version);
 check(Array.isArray(bundle.files)&&bundle.files.length>0&&bundle.files.length<=200,'Invalid file list');
 const names=new Set();let bytes=0;
 for(const f of bundle.files){
  check(allowed(f.path)&&!names.has(f.path),'Invalid or duplicate update path');names.add(f.path);
  check(typeof f.content==='string'&&/^[A-Za-z0-9+/]*={0,2}$/.test(f.content),'Invalid content');
  const data=Buffer.from(f.content,'base64');bytes+=data.length;
  check(data.toString('base64')===f.content&&hash(data)===f.sha256,'Update checksum mismatch');
 }
 check(bytes<=8*1024*1024&&names.has('fxmanifest.lua'),'Invalid update size or manifest');
 const manifest=Buffer.from(bundle.files.find(f=>f.path==='fxmanifest.lua').content,'base64').toString();
 check(manifest.includes("version '"+bundle.version+"'"),'Version does not match resource manifest');
 return bundle;
}
// Adapter methods are synchronous. The resource start gate stays closed during writes.
function createEngine(io){
 function restore(j){
  check(j?.format===1&&Array.isArray(j.before),'Invalid recovery journal');
  for(const f of j.before){
   check(allowed(f.path)||f.path==='update-state.json','Invalid recovery path');
   if(f.content!==null)check(hash(Buffer.from(f.content,'base64'))===f.sha256,'Recovery checksum mismatch');
  }
  for(const f of j.before){if(f.content===null)io.remove(f.path);else io.write(f.path,Buffer.from(f.content,'base64'));}
  for(const f of j.before)check(f.content===null?io.read(f.path)===null:hash(io.read(f.path))===f.sha256,'Recovery verification failed');
  io.clearJournal();
 }
 function recover(){const j=io.readJournal();if(j)restore(j);}
 function apply(bundle){
  validate(bundle);check(!io.readJournal(),'Pending recovery must complete first');
  const stateBytes=io.read('update-state.json');check(stateBytes,'Install an updater-ready release manually first');
  const state=JSON.parse(stateBytes.toString());check(state.format===1&&state.compatibility===1&&Array.isArray(state.files),'Invalid installed state');
  if(!newer(bundle.version,state.version))return false;
  const old=new Map();
  for(const f of state.files){check(allowed(f.path)&&!old.has(f.path),'Invalid installed path');old.set(f.path,f.sha256);}
  // Same managed path set only: additions/removals/dependency/schema/config changes are manual upgrades.
  check(old.size===bundle.files.length&&bundle.files.every(f=>old.has(f.path)),'Managed files changed; manual installation required');
  const before=[];
  for(const f of bundle.files){const data=io.read(f.path);check(data&&hash(data)===old.get(f.path),'Local code was modified; manual merge required');before.push({path:f.path,content:data.toString('base64'),sha256:hash(data)});}
  before.push({path:'update-state.json',content:stateBytes.toString('base64'),sha256:hash(stateBytes)});
  const journal={format:1,from:state.version,to:bundle.version,before};
  io.saveJournal(journal); // Must write AND read-verify before any target mutation.
  check(hash(Buffer.from(JSON.stringify(io.readJournal())))===hash(Buffer.from(JSON.stringify(journal))),'Journal verification failed');
  try {
   for(const f of bundle.files){io.write(f.path,Buffer.from(f.content,'base64'));check(hash(io.read(f.path))===f.sha256,'Installed file verification failed');}
   const next={format:1,compatibility:1,version:bundle.version,files:bundle.files.map(({path,sha256})=>({path,sha256}))};
   const data=Buffer.from(JSON.stringify(next));io.write('update-state.json',data);check(hash(io.read('update-state.json'))===hash(data),'Installed state verification failed');
   io.clearJournal();return true;
  } catch(error){restore(journal);throw error;}
 }
 return {recover,apply};
}
module.exports={hash,allowed,newer,validate,createEngine};
