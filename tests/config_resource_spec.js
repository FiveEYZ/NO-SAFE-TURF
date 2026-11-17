'use strict';
const assert=require('node:assert/strict'),vm=require('node:vm'),fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'../resource');
function run(password,raw=false){
 const values={nst_db_connection:'mysql://user:'+(raw?password:encodeURIComponent(password))+'@db.example:3306/tx_generated'};const logs=[];
 vm.runInNewContext(fs.readFileSync(path.join(__dirname,'../database_config/server.js'),'utf8'),{
  require,GetResourcePath:name=>name==='nst_database_config'?path.resolve(root,'../database_config'):root,GetConvar:(name,otherwise)=>values[name]??otherwise,SetConvar:(name,value)=>{values[name]=value;},console:{error:text=>logs.push(text)}
 });return {values,logs};
}
const good=run('a/b:@?%');assert.equal(good.values.nst_db_configured,'1');assert(good.values.mysql_connection_string.includes('password=a/b:@?%'));assert.equal(good.logs.length,0);
const txAdmin=run('example/slash',true);assert.equal(txAdmin.values.nst_db_configured,'1');assert(txAdmin.values.mysql_connection_string.includes('password=example/slash'));assert.equal(txAdmin.logs.length,0);
for(const password of ['secret;bad','secret=bad','secret_mysql://bad']){
 const result=run(password);assert.equal(result.values.nst_db_configured,'0');assert(!result.values.mysql_connection_string.includes(password));assert.equal(result.logs.length,1);assert(!result.logs[0].includes(password));
}
console.log('PASS: preloader converts txAdmin URL, starts closed and rejects unsupported credentials without logging them');
