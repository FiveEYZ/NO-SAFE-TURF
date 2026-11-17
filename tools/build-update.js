'use strict';
const fs=require('node:fs'),path=require('node:path');
const {hash,allowed,validate}=require('../updater/engine');
const root=path.resolve(__dirname,'..'),resource=path.join(root,'resource');
const version=require('../package.json').version;
const files=[];
function scan(dir){for(const entry of fs.readdirSync(path.join(resource,dir),{withFileTypes:true})){const name=dir?dir+'/'+entry.name:entry.name;if(entry.isDirectory()){if(['client','server','shared','web'].includes(name)||dir)scan(name);}else if(allowed(name)){const content=fs.readFileSync(path.join(resource,name));files.push({path:name,sha256:hash(content),content:content.toString('base64')});}}}
scan('');files.sort((a,b)=>a.path.localeCompare(b.path));
const bundle=validate({format:1,compatibility:1,version,files});
fs.mkdirSync(path.join(root,'dist'),{recursive:true});
const data=Buffer.from(JSON.stringify(bundle));
fs.writeFileSync(path.join(root,'dist/nst-update.json'),data);
fs.writeFileSync(path.join(resource,'update-state.json'),JSON.stringify({format:1,compatibility:1,version,files:files.map(({path,sha256})=>({path,sha256}))}));
fs.writeFileSync(path.join(root,'dist/stable.json'),JSON.stringify({format:1,version,url:`https://github.com/FiveEYZ/NO-SAFE-TURF/releases/download/v${version}/nst-update.json`,sha256:hash(data)},null,2)+'\n');
console.log('Built verified update bundle and installed-state baseline for '+version);
