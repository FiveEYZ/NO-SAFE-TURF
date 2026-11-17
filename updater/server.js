'use strict';
const fs=require('node:fs'),path=require('node:path'),https=require('node:https');
const self=GetCurrentResourceName(),target='no_safe_turf';
const root=GetResourcePath(self),targetRoot=GetResourcePath(target);
const {createEngine,hash,newer}=require(path.join(root,'engine.js'));
const feed='https://raw.githubusercontent.com/FiveEYZ/NO-SAFE-TURF/main/updates/stable.json';
let gate=true,blocked=false;
const log=message=>console.log('[NST Updater] '+message);
function durable(file,data){const fd=fs.openSync(file,'w');try{fs.writeFileSync(fd,data);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}}
function syncDirectory(dir){const fd=fs.openSync(dir,'r');try{fs.fsyncSync(fd);}finally{fs.closeSync(fd);}}
const journalPath=path.join(root,'pending-update.json');
function pending(){try{return fs.readFileSync(journalPath,'utf8');}catch(e){if(e.code==='ENOENT')return null;throw e;}}
const io={
 read:p=>{try{return fs.readFileSync(path.join(targetRoot,p));}catch(e){if(e.code==='ENOENT')return null;throw e;}},
 write:(p,data)=>durable(path.join(targetRoot,p),data),
 remove:p=>{try{fs.unlinkSync(path.join(targetRoot,p));}catch(e){if(e.code!=='ENOENT')throw e;}},
 readJournal:()=>{const data=pending();return data===null?null:JSON.parse(data);},
 saveJournal:j=>{const data=JSON.stringify(j);const backup=path.join(root,'backups');fs.mkdirSync(backup,{recursive:true});durable(path.join(backup,Date.now()+'.json'),data);syncDirectory(backup);durable(journalPath,data);syncDirectory(root);},
 clearJournal:()=>{try{fs.unlinkSync(journalPath);}catch(e){if(e.code!=='ENOENT')throw e;}syncDirectory(root);}
};
function download(url,limit,redirects=0){
 return new Promise((resolve,reject)=>{
  const u=new URL(url);const hosts=['raw.githubusercontent.com','github.com','release-assets.githubusercontent.com'];
  if(u.protocol!=='https:'||!hosts.includes(u.hostname)||redirects>4)return reject(new Error('Untrusted download address'));
  const request=https.get(u,{headers:{'User-Agent':'NST-Updater/1'}},response=>{
   if([301,302,303,307,308].includes(response.statusCode)){response.resume();try{if(!response.headers.location)throw new Error('Missing redirect');download(new URL(response.headers.location,u).href,limit,redirects+1).then(resolve,reject);}catch(e){reject(e);}return;}
   if(response.statusCode!==200){response.resume();return reject(new Error('Update endpoint unavailable'));}
   const parts=[];let size=0;response.on('data',chunk=>{size+=chunk.length;if(size>limit){request.destroy(new Error('Update exceeds size limit'));return;}parts.push(chunk);});
   response.on('end',()=>resolve(Buffer.concat(parts)));response.on('error',reject);
  });
  const timer=setTimeout(()=>request.destroy(new Error('Update request timed out')),20000);
  request.on('close',()=>clearTimeout(timer));request.on('error',reject);
 });
}
on('onResourceStarting',name=>{if(name===target&&gate){CancelEvent();log('Holding game resource startup until update checks finish.');}});
on('playerConnecting',(_name,_kick,deferrals)=>{if(gate){deferrals.defer();setTimeout(()=>deferrals.done('Server startup maintenance. Please reconnect shortly.'),0);}});
RegisterCommand('nst_update_status',source=>{if(source===0)log(blocked?'Blocked: inspect updater backup and console.':gate?'Checking updates.':'Startup check completed.');},false);
async function start(){
 if(!targetRoot)throw new Error('Game resource was not found');
 if(GetResourceState(target)==='started'||GetNumPlayerIndices()>0){
  if(pending()!==null){blocked=true;log('Pending recovery requires a full server restart.');return;}
  gate=false;log('Live update skipped. Use a full server restart to check updates.');return;
 }
 const engine=createEngine(io);
 try{engine.recover();}catch{blocked=true;log('Recovery failed. Game startup remains blocked; preserve pending-update.json and backups.');return;}
 try{
  if(GetConvarInt('nst_auto_update',0)===1){
   const descriptor=JSON.parse((await download(feed,16384)).toString());
   if(descriptor.format!==1||!/^https:\/\/github\.com\/FiveEYZ\/NO-SAFE-TURF\/releases\/download\/v\d+\.\d+\.\d+\/nst-update\.json$/.test(descriptor.url)||!/^[a-f0-9]{64}$/.test(descriptor.sha256))throw new Error('Invalid update feed');
   const current=JSON.parse(io.read('update-state.json').toString());
   if(newer(descriptor.version,current.version)){
    const bytes=await download(descriptor.url,12*1024*1024);if(hash(bytes)!==descriptor.sha256)throw new Error('Package checksum mismatch');
    const bundle=JSON.parse(bytes.toString());if(bundle.version!==descriptor.version)throw new Error('Package version mismatch');
    // Resume on the Cfx thread, and check conditions again after network I/O.
    await new Promise((resolve,reject)=>setImmediate(()=>{try{
     if(GetNumPlayerIndices()>0||GetResourceState(target)==='started')throw new Error('Server became active during update');
     log(engine.apply(bundle)?'Update installed and verified.':'Already up to date.');resolve();
    }catch(e){reject(e);}}));
   }else log('Already up to date.');
  }else log('Automatic updates disabled. Existing installation will start.');
 }catch(error){
  // A pending journal means target integrity is not yet established.
  let unresolved=true;try{unresolved=pending()!==null;}catch{}
  if(unresolved){blocked=true;log('Update incomplete. Startup blocked until recovery succeeds.');return;}
  log('Update skipped: '+error.message+'. Existing installation retained.');
 }
 setImmediate(()=>{gate=false;StartResource(target);});
}
setImmediate(()=>start().catch(()=>{blocked=true;log('Startup check failed; game startup is blocked.');}));
