'use strict';
const fs=require('node:fs'),path=require('node:path');
const {LuaFactory}=require('wasmoon');
const root=path.resolve(__dirname,'..');
function files(dir){return fs.readdirSync(path.join(root,dir),{withFileTypes:true}).flatMap(e=>e.name==='node_modules'?[]:e.isDirectory()?files(dir+'/'+e.name):[dir+'/'+e.name]);}
async function main(){
  const factory=new LuaFactory();
  const manifest=fs.readFileSync(path.join(root,'resource/fxmanifest.lua'),'utf8');
  const shared=[...manifest.match(/shared_scripts\s*\{([^}]+)\}/)[1].matchAll(/'([^']+)'/g)].map(m=>'resource/'+m[1]);
  const serverLocales=[...manifest.match(/server_scripts\s*\{([^}]+)\}/)[1].matchAll(/'(server\/locales\/[^']+)'/g)].map(m=>'resource/'+m[1]);
  const sources=[...files('resource'),...files('tests')].filter(p=>p.endsWith('.lua'));
  for(const p of sources)await factory.mountFile(p,fs.readFileSync(path.join(root,p),'utf8').replace(/^\uFEFF/,''));
  const compile=await factory.createEngine();
  try {for(const p of sources)await compile.doString('assert(loadfile('+JSON.stringify(p)+'))');}finally{compile.global.close();}
  for(const p of sources.filter(p=>p.startsWith('tests/')&&p.endsWith('_spec.lua'))){
    const lua=await factory.createEngine();
    try {
      for(const script of [...shared,...serverLocales])await lua.doFile(script);
      await lua.doFile(p);
    }finally{lua.global.close();}
  }
  console.log('PASS: Lua 5.4 compilation and module/adapter specs via Wasmoon; no Python.');
}
main().catch(e=>{console.error(e);process.exitCode=1;});
