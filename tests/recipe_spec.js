'use strict';
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const {execFileSync}=require('node:child_process');
const YAML=require('yaml');
const root=path.resolve(__dirname,'..');
const recipe=YAML.parse(fs.readFileSync(path.join(root,'recipe.yaml'),'utf8'));
assert.equal(recipe.$engine,3);assert.equal(recipe.$onesync,'on');
assert.equal(recipe.$minFxVersion,undefined,'Do not apply a Legacy artifact threshold to Enhanced');
const actions=new Set(['write_file','load_vars','connect_database','download_file','unzip','query_database','download_github','move_path','remove_path','replace_string']);
for(const task of recipe.tasks)assert(actions.has(task.action),'Unsupported action '+task.action);
const compatibility=recipe.tasks.find(t=>t.action==='replace_string');
assert.equal(compatibility.search,'/server:12913');assert.equal(compatibility.replace,'/server:177');
assert(recipe.tasks.find(t=>t.action==='download_file').url.includes('/v'+recipe.version+'/'));
const cfg=fs.readFileSync(path.join(root,'deploy/recipe-server.cfg'),'utf8');
for(const key of ['maxClients','addPrincipalsMaster','serverEndpoints','svLicense','dbConnectionString'])assert(cfg.includes('{{'+key+'}}'));
for(const name of ['nst_database_config','oxmysql','no_safe_turf'])assert(cfg.includes('ensure '+name));
assert(cfg.indexOf('ensure nst_database_config')<cfg.indexOf('ensure oxmysql'));assert(cfg.indexOf('ensure oxmysql')<cfg.indexOf('ensure no_safe_turf'));
assert(!cfg.includes('setr nst_db_connection'));assert(!cfg.includes('sets nst_db_connection'));
assert.equal(recipe.tasks.find(t=>t.action==='download_github').ref,'32d98e7524b952faf8b220d719615b0346b0a6cc');
if(!process.argv.includes('--files')){console.log('PASS: recipe YAML, documented actions, pinned reference, placeholders and startup order');process.exit(0);}
const work=path.join(root,'.testdata','recipe-'+crypto.randomUUID());fs.mkdirSync(work,{recursive:true});
const resolve=p=>{const result=path.resolve(work,p);assert(result.startsWith(work+path.sep),'Path escaped disposable fixture');return result;};
const inputs=path.join(root,'.testtools/release-inputs');
function unzip(source,dest){fs.mkdirSync(dest,{recursive:true});execFileSync('tar',['-xf',source,'-C',dest],{stdio:'pipe',windowsHide:true});}
for(const [file,hash] of [['oxmysql-2.14.3.zip','f6db8f612a36a8a75fccde300e8c4135696b5bbca5770cd7f26458949e1f7872'],['cfx-server-data.zip','7a394dc03e0b0999dd13269ea471436b00e80dcdee974d7cd727ffaca95e733b']])assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(inputs,file))).digest('hex'),hash);
const context={};let sql=0;
for(const task of recipe.tasks){
 switch(task.action){
  case 'write_file':{const target=resolve(task.file);fs.mkdirSync(path.dirname(target),{recursive:true});fs.writeFileSync(target,task.data);break;}
  case 'load_vars':Object.assign(context,JSON.parse(fs.readFileSync(resolve(task.src),'utf8')));break;
  case 'connect_database':assert.equal(context.dbDelete,false);break; // Real SQL covered by disposable DB suite.
  case 'download_file':{
   const source=task.url.includes('/overextended/oxmysql/')?path.join(inputs,'oxmysql-2.14.3.zip'):path.join(root,'dist/no-safe-turf-txadmin.zip');
   const dest=resolve(task.path);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.copyFileSync(source,dest);break;
  }
  case 'unzip':unzip(resolve(task.src),resolve(task.dest));break;
  case 'query_database':assert(fs.readFileSync(resolve(task.file),'utf8').includes('nst_'));sql++;break;
  case 'download_github':{
   const extracted=resolve('./cfx-fixture');unzip(path.join(inputs,'cfx-server-data.zip'),extracted);
   const top=fs.readdirSync(extracted)[0];fs.cpSync(path.join(extracted,top,task.subpath),resolve(task.dest),{recursive:true});break;
  }
  case 'move_path':{const dest=resolve(task.dest);assert(!fs.existsSync(dest));fs.mkdirSync(path.dirname(dest),{recursive:true});fs.renameSync(resolve(task.src),dest);break;}
  case 'replace_string':{
   assert.equal(task.mode,'literal');const file=resolve(task.file);const original=fs.readFileSync(file,'utf8');
   assert.equal(original.split(task.search).length-1,1,'Pinned manifest must contain exactly one Legacy constraint');
   fs.writeFileSync(file,original.replace(new RegExp(task.search,'g'),task.replace));break;
  }
  case 'remove_path':fs.rmSync(resolve(task.path),{recursive:true,force:true});break;
 }
}
assert.equal(sql,2);
const oxManifest=fs.readFileSync(resolve('resources/[standalone]/oxmysql/fxmanifest.lua'),'utf8');
assert(oxManifest.includes('/server:177'));assert(!oxManifest.includes('/server:12913'));
assert(oxManifest.includes("node_version '22'"));assert(oxManifest.includes("version '2.14.3'"));
for(const p of ['server.cfg','resources/[local]/nst_database_config/fxmanifest.lua','resources/[local]/no_safe_turf/fxmanifest.lua','resources/[local]/no_safe_turf/web/app.js','resources/[standalone]/oxmysql/dist/build.js','resources/mapmanager/fxmanifest.lua','resources/spawnmanager/fxmanifest.lua'])assert(fs.existsSync(resolve(p)),p);
console.log('PASS: local recipe file replay using verified upstream ZIPs; no txAdmin runtime/database deployment. Artifacts: '+path.relative(root,work));
