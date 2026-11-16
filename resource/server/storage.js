'use strict';
// Entry point executed only by the FiveM SERVER JavaScript runtime.
const path = require('node:path');
const resourceName = GetCurrentResourceName();
const root = GetResourcePath(resourceName);
const {safeError} = require(path.join(root,'server/storage/config.js'));
const L=require(path.join(root,'server/storage/locale_en.js'));
const {createBridge} = require(path.join(root,'server/storage/bridge.js'));
const {Schedule} = require(path.join(root,'server/storage/schedule.js'));
const {createBackupWriter} = require(path.join(root,'server/storage/backup.js'));
let bridge,backupArmed=false;
try {
  if(GetConvarInt('nst_db_configured',0)!==1)throw new Error('Database configuration is not ready');
  const {createOxPool}=require(path.join(root,'server/storage/oxmysql.js'));
  const {MariaDBStore} = require(path.join(root,'server/storage/store.js'));
  const pool = createOxPool(exports.oxmysql,fn=>setImmediate(fn));
  const schedule = new Schedule(GetConvarInt('nst_wipe_weekday',6),GetConvarInt('nst_wipe_hour',4),GetConvarInt('nst_wipe_minute',0));
  const backupWriter=createBackupWriter(root,GetConvar('nst_backup_directory',''));
  backupArmed=Boolean(backupWriter);
  bridge = createBridge(new MariaDBStore({pool,schedule,backupWriter}),{seedMissingMeta:GetConvarInt('nst_db_bootstrap',0)===1});
} catch (error) { console.error('[NST] '+safeError(error)); }

// Callback results return on the game thread, as required by Cfx Node natives.
exports('storageRequest',(route,method,body,callback)=>{
  if (typeof callback!=='function') return;
  const task = bridge ? bridge.request(route,method,body) : Promise.resolve({code:503,data:{error:L.configuration}});
  task.then(result=>setImmediate(()=>callback(result.code,JSON.stringify(result.data))))
      .catch(()=>setImmediate(()=>callback(503,JSON.stringify({error:L.unavailable}))));
});

RegisterCommand('nst_db_status',(source)=>{
  if (source!==0) return; // Server console only; never disclose connection details.
  if (!bridge) {console.log('[NST] '+L.configuration);return;}
  bridge.ready().then(()=>console.log('[NST] '+L.ready+' '+(backupArmed?L.backupArmed:L.backupMissing)))
    .catch(error=>console.error('[NST] '+safeError(error)));
},false);

on('onResourceStop',name=>{if(name===resourceName && bridge) bridge.stop().catch(()=>{});});
