'use strict';
// Offline Node tool: check is read-only; initialization and restore are explicit.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..');
const mysql=require('../resource/node_modules/mysql2/promise');
const {readConfig,safeError}=require('../resource/server/storage/config');
const {MariaDBStore}=require('../resource/server/storage/store');
const {Schedule}=require('../resource/server/storage/schedule');

async function main() {
  const [command,...args]=process.argv.slice(2),options={};
  for(let i=0;i<args.length;i++) {
    if(args[i]==='--reschedule') options.reschedule=true;
    else if(['--config','--file','--id','--weekday','--hour','--minute'].includes(args[i]) && args[i+1]!==undefined) options[args[i].slice(2)]=args[++i];
    else throw new Error('Invalid arguments');
  }
  if(!['check','init','export','restore'].includes(command)) {
    console.log('node tools/database.js check|init|export|restore --config PRIVATE_JSON [--id BACKUP_ID --file FILE] [--reschedule]');return;
  }
  if(!options.config) throw new Error('A private config file is required');
  if((command==='export' && (!options.id || !options.file)) || (command==='restore' && !options.file)) throw new Error('Missing backup arguments');
  const schedule=new Schedule(Number(options.weekday??6),Number(options.hour??4),Number(options.minute??0));
  const pool=mysql.createPool(readConfig(path.resolve(options.config)));
  try {
    if(command==='check') {
      const connection=await pool.getConnection();
      try {
        await connection.query('START TRANSACTION READ ONLY');
        const [[version]]=await connection.query('SELECT VERSION() AS version');
        const [[tables]]=await connection.query('SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema=DATABASE()');
        const [[meta]]=await connection.query("SELECT COUNT(*) AS n FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='nst_meta'");
        await connection.rollback();
        console.log('Database version:',version.version);
        console.log('Table count:',tables.n,'; NO SAFE TURF metadata present:',Number(meta.n)>0);
        console.log('Read-only check passed. No data changed.');
      } finally {connection.release();}
      return;
    }
    const store=new MariaDBStore({pool,schedule});
    await store.initialize({createSchema:command==='init',schemaSql:fs.readFileSync(path.join(root,'database/mariadb/001_initial.sql'),'utf8')});
    if(command==='init') console.log('Schema initialized. No game server started.');
    if(command==='export') {
      const archive=await store.exportBackup(options.id);
      fs.writeFileSync(options.file,JSON.stringify(archive),{encoding:'utf8',flag:'wx',mode:0o600});
      console.log('Backup exported to a new file.');
    }
    if(command==='restore') {
      await store.restoreArchive(JSON.parse(fs.readFileSync(options.file,'utf8')),{reschedule:options.reschedule??false});
      console.log('Backup restored to the empty destination database.');
    }
  } finally {await pool.end();}
}
main().catch(error=>{console.error(safeError(error));process.exitCode=1;});
