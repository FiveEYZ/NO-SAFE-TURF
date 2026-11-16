'use strict';
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const {MariaDBStore, Conflict} = require('../resource/server/storage/store');
const {Schedule} = require('../resource/server/storage/schedule');
const {createBackupWriter}=require('../resource/server/storage/backup');
const {createOxPool}=require('../resource/server/storage/oxmysql');
const schemaSql = fs.readFileSync(path.join(__dirname,'../database/mariadb/001_initial.sql'),'utf8');
const clone = value => JSON.parse(JSON.stringify(value));

async function runIntegration({mysql,config,admin,output}) {
  let count=0;
  async function test(name,fn) {
    const pools=[];
    const clock={now:1794672000};
    async function fresh() {
      const database='nst_node_test_'+crypto.randomBytes(12).toString('hex');
      await admin.query('CREATE DATABASE '+database+' CHARACTER SET utf8mb4 COLLATE utf8mb4_bin');
      const pool=mysql.createPool({...config,database,connectionLimit:4,charset:'utf8mb4',supportBigNumbers:true,bigNumberStrings:false});
      pools.push(pool);
      await pool.query(fs.readFileSync(path.join(__dirname,'../database/mariadb/000_recipe_preflight.sql'),'utf8'));
      const store=new MariaDBStore({pool,schedule:new Schedule(),clock:()=>clock.now,backupWriter:createBackupWriter(output,'verified-backups')});
      await store.initialize({createSchema:true,schemaSql});
      return {database,pool,store};
    }
    const fixture=await fresh();
    try {
      await fn({...fixture,clock,fresh,pools});
      count++;console.log('PASS:',name);
    } finally {
      await Promise.allSettled(pools.map(pool=>pool.end()));
      // Keep disposable DB files for inspection; never DROP an existing database.
    }
  }
  async function seed(store) {
    const initial=await store.state();
    initial.state.players={a:{cash:500,items:{stolen:6,bat:1}},b:{cash:500,items:{}}};
    initial.state.gangs={a:{name:'Concrete',score:12,bank:100,items:{stolen:8}}};
    return store.commit(initial.revision,initial.state,{action:'seed',actor:'test'});
  }
  const rejectedConflict = error => error instanceof Conflict || error.code==='CONFLICT';
  await test('fresh-install SQL guard rejects existing NST schema without changing data',async({pool,store})=>{
    const before=await seed(store);
    await assert.rejects(()=>pool.query(fs.readFileSync(path.join(__dirname,'../database/mariadb/000_recipe_preflight.sql'),'utf8')));
    assert.deepEqual(await store.state(),before);
  });

  await test('oxmysql transport contract over live MariaDB commits, rolls back and restores',async({pool,clock,fresh})=>{
    const api={query_async:async(sql,args)=>(await pool.query(sql,args))[0],startTransaction:async cb=>{
      const c=await pool.getConnection();try{await c.beginTransaction();const ok=await cb(async(sql,args)=>(await c.query(sql,args))[0]);if(ok===false){await c.rollback();return false;}await c.commit();return true;}catch(e){await c.rollback();throw e;}finally{c.release();}
    }};
    const transport=createOxPool(api,fn=>setImmediate(fn));
    const store=new MariaDBStore({pool:transport,schedule:new Schedule(),clock:()=>clock.now,backupWriter:createBackupWriter(output,'ox-backups')});
    await store.initialize();const before=await seed(store);
    await assert.rejects(()=>store.commit(0,before.state,{}),rejectedConflict);
    assert.deepEqual(await store.state(),before);
    const wiped=await store.wipe('ox-contract');const archive=await store.exportBackup(wiped.backup);
    const target=await fresh();await target.store.restoreArchive(archive,{reschedule:true});assert.deepEqual((await target.store.state()).state,before.state);
    await transport.end();
  });

  await test('backup failure blocks manual and scheduled wipe without changing state',async({store,pool,clock})=>{
    const before=await seed(store); const writer=store.backupWriter;
    store.backupWriter=async()=>{throw new Error('Test disk unavailable');};
    await assert.rejects(()=>store.wipe('failed-backup'),e=>e.code==='BACKUP_UNAVAILABLE');
    assert.deepEqual(await store.state(),before);
    const [[row]]=await pool.query('SELECT COUNT(*) AS n FROM nst_backups');assert.equal(Number(row.n),0);
    clock.now=before.nextWipe;
    await assert.rejects(()=>store.state(),e=>e.code==='BACKUP_UNAVAILABLE');
    const [[meta]]=await pool.query('SELECT revision,season FROM nst_meta');assert.equal(Number(meta.revision),before.revision);assert.equal(Number(meta.season),before.state.season);
    store.backupWriter=writer;assert.equal((await store.state()).state.season,before.state.season+1);
  });

  await test('verified on-disk archive restores independently of original database',async({store,fresh})=>{
    const before=await seed(store);const result=await store.wipe('disk-restore');
    const filename=fs.readdirSync(path.join(output,'verified-backups')).find(f=>f.startsWith(result.backup+'-')&&f.endsWith('.backup.json'));
    assert(filename);const archive=JSON.parse(fs.readFileSync(path.join(output,'verified-backups',filename),'utf8'));
    const target=await fresh();await target.store.restoreArchive(archive,{reschedule:true});
    assert.deepEqual((await target.store.state()).state,before.state);
  });

  await test('connection loss before commit rolls back and pool reconnects',async({store,pool})=>{
    const before=await seed(store);const next=clone(before.state);next.players.a.cash+=100;
    const original=store.write.bind(store);
    store.write=async(connection,old,value)=>{
      await original(connection,old,value);
      const [[row]]=await connection.query('SELECT CONNECTION_ID() AS id');
      await admin.query('KILL CONNECTION '+Number(row.id));
    };
    await assert.rejects(()=>store.commit(before.revision,next,{action:'network-failure'}));
    store.write=original;
    assert.deepEqual(await store.state(),before);
    assert.equal((await store.commit(before.revision,next,{action:'reconnected'})).state.players.a.cash,before.state.players.a.cash+100);
  });

  await test('recipe bootstrap requires empty tables and preserves an existing deadline',async({store,pool})=>{
    const before=await store.state();
    await store.initialize({seedMissingMeta:true});
    assert.deepEqual(await store.state(),before);
    await pool.query('DELETE FROM nst_meta');
    await assert.rejects(()=>store.initialize(),/not initialized/);
    await store.initialize({seedMissingMeta:true});
    const seeded=await store.state();assert.equal(seeded.state.season,1);assert.equal(seeded.nextWipe,before.nextWipe);
    await seed(store);
    await pool.query('DELETE FROM nst_meta');
    await assert.rejects(()=>store.initialize({seedMissingMeta:true}),/occupied/);
    await assert.rejects(()=>store.initialize({createSchema:true,schemaSql}),/occupied/);
    const [[row]]=await pool.query('SELECT COUNT(*) AS n FROM nst_meta');assert.equal(Number(row.n),0);
  });

  await test('schema, inventory round trip and stale revision',async({store,pool})=>{
    let saved=await seed(store);
    assert.deepEqual((await store.state()).state,saved.state);
    const [[row]]=await pool.query("SELECT payload FROM nst_players WHERE entity_id='a'");
    assert.equal(Object.hasOwn(JSON.parse(row.payload),'items'),false);
    const [[items]]=await pool.query('SELECT COUNT(*) AS n FROM nst_player_items');assert.equal(items.n,2);
    await assert.rejects(()=>store.commit(0,saved.state,{}),rejectedConflict);
    saved.state.players.a.items.stolen=2;
    saved=await store.commit(saved.revision,saved.state,{});
    assert.equal(saved.revision,2);assert.equal((await store.state()).state.players.a.items.stolen,2);
  });

  await test('two independent pools claim one drop',async({store,database,pools,clock})=>{
    let initial=await seed(store);
    initial.state.drops.one={items:{stolen:1}};
    initial=await store.commit(initial.revision,initial.state,{});
    async function claim(player) {
      const pool=mysql.createPool({...config,database,connectionLimit:2});pools.push(pool);
      const rival=new MariaDBStore({pool,schedule:new Schedule(),clock:()=>clock.now});await rival.initialize();
      const next=clone(initial.state);delete next.drops.one;
      next.players[player].items.stolen=(next.players[player].items.stolen||0)+1;
      try {await rival.commit(initial.revision,next,{action:'loot'});return true;}
      catch(error) {if(rejectedConflict(error)) return false;throw error;}
    }
    const outcomes=await Promise.all([claim('a'),claim('b')]);assert.equal(outcomes.filter(Boolean).length,1);
    assert.equal((await store.state()).state.drops.one,undefined);
  });

  await test('only changed entity/item rows are written',async({store,pool})=>{
    let saved=await seed(store);
    await pool.query('CREATE TABLE nst_test_counter(n INT NOT NULL) ENGINE=InnoDB');
    await pool.query('INSERT INTO nst_test_counter VALUES(0)');
    await pool.query('CREATE TRIGGER nst_test_player_updated BEFORE UPDATE ON nst_players FOR EACH ROW UPDATE nst_test_counter SET n=n+1');
    saved.state.players.a.items.stolen=4;saved=await store.commit(saved.revision,saved.state,{});
    assert.equal((await pool.query('SELECT n FROM nst_test_counter'))[0][0].n,0);
    saved.state.players.a.cash=490;await store.commit(saved.revision,saved.state,{});
    assert.equal((await pool.query('SELECT n FROM nst_test_counter'))[0][0].n,1);
  });

  await test('wipe preserves persistent data and is idempotent',async({store,pool})=>{
    await seed(store);
    await pool.query("INSERT INTO nst_accounts VALUES('admin',1,'{}')");
    await pool.query("INSERT INTO nst_bans VALUES('banned','test',NULL)");
    await pool.query("INSERT INTO nst_settings VALUES('setting','true')");
    assert.equal((await store.wipe('weekly-test',true)).revision,1);
    const result=await store.wipe('weekly-test');assert.equal(result.state.season,2);assert.deepEqual(result.state.players,{});
    const repeat=await store.wipe('weekly-test');assert.equal(repeat.revision,result.revision);assert.equal(repeat.alreadyDone,true);
    for(const table of ['accounts','bans','settings','backups','season_history','wipes']) {
      assert.equal((await pool.query('SELECT COUNT(*) AS n FROM nst_'+table))[0][0].n,1);
    }
  });

  await test('wipe recovery before and after commit',async({store,pool,clock})=>{
    await seed(store);
    for(const stage of ['after_backup','before_commit','after_commit']) {
      const before=await store.state();
      store.failpoint=point=>{if(point===stage)throw new Error('simulated process failure');};
      await assert.rejects(()=>store.wipe(stage),/simulated process failure/);
      store.failpoint=null;
      const reopened=new MariaDBStore({pool,schedule:new Schedule(),clock:()=>clock.now,backupWriter:createBackupWriter(output,'verified-backups')});await reopened.initialize();
      await reopened.wipe(stage);
      assert.equal((await reopened.state()).state.season,before.state.season+1);
      assert.equal((await reopened.wipe(stage)).alreadyDone,true);
    }
  });

  await test('overdue wipe invalidates gameplay commit',async({store,clock})=>{
    const old=await seed(store);clock.now=old.nextWipe+1;
    await assert.rejects(()=>store.commit(old.revision,old.state,{}),rejectedConflict);
    assert.equal((await store.state()).state.season,2);
  });

  await test('backup round trip with historical ledger and corruption rejection',async({store,fresh,clock})=>{
    await seed(store);await store.wipe('first');
    let saved=await store.state();saved.state.players.restored={cash:123,items:{bat:1}};
    saved=await store.commit(saved.revision,saved.state,{});
    const wiped=await store.wipe('second');
    const archive=await store.exportBackup(wiped.backup);
    fs.writeFileSync(path.join(output,'node-roundtrip.backup.json'),JSON.stringify(archive),{flag:'wx'});
    await assert.rejects(()=>store.restoreArchive(archive,{reschedule:true}));
    const target=await fresh();clock.now+=604800;
    await target.store.restoreArchive(archive,{reschedule:true});
    assert.deepEqual((await target.store.state()).state,saved.state);
    assert.equal((await target.store.wipe('first')).alreadyDone,true);
    const bad=clone(archive);bad.backups[0].payload='{}';
    const clean=await fresh();await assert.rejects(()=>clean.store.restoreArchive(bad));
    assert.equal((await clean.store.state()).state.season,1);
  });

  await test('invalid season, inventory and ambiguous identifiers are rejected',async({store})=>{
    const before=await seed(store);
    let candidate=clone(before.state);candidate.season=99;
    await assert.rejects(()=>store.commit(before.revision,candidate,{}));
    for(const amount of [-1,0.5,true,Number.MAX_SAFE_INTEGER+1]) {
      candidate=clone(before.state);candidate.players.a.items.stolen=amount;
      await assert.rejects(()=>store.commit(before.revision,candidate,{}));
    }
    candidate=clone(before.state);candidate.players['ambiguous ']=candidate.players.b;
    await assert.rejects(()=>store.commit(before.revision,candidate,{}));
    assert.deepEqual((await store.state()).state,before.state);
  });

  await test('gameplay commit rolls back changed rows on SQL failure',async({store,pool})=>{
    const before=await seed(store);
    await pool.query("CREATE TRIGGER nst_test_deny_audit BEFORE INSERT ON nst_audit FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT='simulated audit failure'");
    const candidate=clone(before.state);candidate.players.a.cash=999;
    await assert.rejects(()=>store.commit(before.revision,candidate,{action:'test'}),/simulated audit failure/);
    assert.deepEqual((await store.state()).state,before.state);
  });
  console.log(`PASS: ${count} real MariaDB Node integration cases`);
}

module.exports={runIntegration};
