'use strict';
const {spawnSync}=require('node:child_process');
const fs=require('node:fs'),path=require('node:path');
process.chdir(path.resolve(__dirname,'..'));
function run(args){const r=spawnSync(process.execPath,args,{stdio:'inherit',windowsHide:true});if(r.error)throw r.error;if(r.status!==0)process.exit(r.status||1);}
function syntax(dir){for(const entry of fs.readdirSync(dir,{withFileTypes:true})){if(entry.name==='node_modules')continue;const p=path.join(dir,entry.name);if(entry.isDirectory())syntax(p);else if(p.endsWith('.js'))run(['--check',p]);}}
syntax('updater');syntax('resource');syntax('database_config');syntax('tools');syntax('tests');
for(const file of ['updater_resource_spec.js','updater_spec.js','schedule_spec.js','config_spec.js','oxmysql_spec.js','config_resource_spec.js','bridge_spec.js','web_spec.js','recipe_spec.js'])run(['tests/'+file]);
console.log('PASS: Node checks; no database connection or Python required.');

