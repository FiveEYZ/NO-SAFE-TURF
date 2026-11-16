'use strict';
// Entry point executed only by the FiveM SERVER JavaScript runtime.
const fs = require('node:fs');
const path = require('node:path');
const resourceName = GetCurrentResourceName();
const root = GetResourcePath(resourceName);
const {readConfig,connectionConfig,safeError} = require(path.join(root,'server/storage/config.js'));
const {createBridge} = require(path.join(root,'server/storage/bridge.js'));
const {Schedule} = require(path.join(root,'server/storage/schedule.js'));
let bridge;
try {
  const mysql = require(path.join(root,'node_modules/mysql2/promise'));
  const {MariaDBStore} = require(path.join(root,'server/storage/store.js'));
  const configPath = path.resolve(root,GetConvar('nst_db_config','server/mariadb.private.json'));
  const connection = GetConvar('nst_db_connection','');
  const pool = mysql.createPool(connection ? connectionConfig(connection) : readConfig(configPath));
  const schedule = new Schedule(GetConvarInt('nst_wipe_weekday',6),GetConvarInt('nst_wipe_hour',4),GetConvarInt('nst_wipe_minute',0));
  bridge = createBridge(new MariaDBStore({pool,schedule}),{seedMissingMeta:GetConvarInt('nst_db_bootstrap',0)===1});
} catch (error) { console.error('[NST] '+safeError(error)); }

// Callback results return on the game thread, as required by Cfx Node natives.
exports('storageRequest',(route,method,body,callback)=>{
  if (typeof callback!=='function') return;
  const task = bridge ? bridge.request(route,method,body) : Promise.resolve({code:503,data:{error:'Storage configuration is not ready'}});
  task.then(result=>setImmediate(()=>callback(result.code,JSON.stringify(result.data))))
      .catch(()=>setImmediate(()=>callback(503,'{"error":"Storage unavailable"}')));
});

RegisterCommand('nst_db_status',(source)=>{
  if (source!==0) return; // Server console only; never disclose connection details.
  if (!bridge) {console.log('[NST] Storage configuration is not ready.');return;}
  bridge.ready().then(()=>console.log('[NST] MariaDB connection and schema are ready.'))
    .catch(error=>console.error('[NST] '+safeError(error)));
},false);

on('onResourceStop',name=>{if(name===resourceName && bridge) bridge.stop().catch(()=>{});});
