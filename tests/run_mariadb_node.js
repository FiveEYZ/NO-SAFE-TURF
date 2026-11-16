'use strict';
// No Python, installed service, deployment config or production credentials.
// Uses only a freshly initialized disposable server on a temporary loopback port.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const net = require('node:net');
const {spawn} = require('node:child_process');
const {setTimeout: delay} = require('node:timers/promises');
const root = path.resolve(__dirname, '..');

function run(command, args, log, timeout = 60000) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, {windowsHide:true, stdio:['ignore', log, log]});
    const timer = setTimeout(() => { child.kill(); reject(new Error('Test fixture initialization timed out')); }, timeout);
    child.once('error', error => {clearTimeout(timer); reject(error);});
    child.once('exit', code => {clearTimeout(timer); code === 0 ? resolve() : reject(new Error(`Fixture initialization failed (${code}); inspect initialize.log`));});
  });
}

async function freePort() {
  const server = net.createServer();
  await new Promise((resolve, reject) => {server.once('error',reject);server.listen(0, '127.0.0.1',resolve);});
  const port = server.address().port;
  await new Promise(resolve => server.close(resolve));
  return port;
}

async function waitExit(child, timeout) {
  if (child.exitCode !== null || child.signalCode !== null) return true;
  return new Promise(resolve => {
    const timer = setTimeout(() => {child.removeListener('exit',done);resolve(false);},timeout);
    function done() {clearTimeout(timer);resolve(true);}
    child.once('exit',done);
  });
}

async function main() {
  process.chdir(root);
  const mysql = require('../resource/node_modules/mysql2/promise');
  const binaries = path.join(root,'.testtools','mariadb-11.4.5-winx64','bin');
  if (!fs.existsSync(path.join(binaries,'mariadbd.exe'))) throw new Error('Portable MariaDB fixture missing; see docs/MARIADB.md');
  const output = path.join(root,'.testdata','node-'+crypto.randomUUID());
  fs.mkdirSync(output,{recursive:true});
  const data = path.join(output,'data');
  const password = crypto.randomBytes(24).toString('hex');
  const port = await freePort();
  const initializeLog = fs.openSync(path.join(output,'initialize.log'),'w');
  try {
    await run(path.join(binaries,'mariadb-install-db.exe'),['--datadir='+data,'--password='+password,'--port='+port],initializeLog);
  } finally { fs.closeSync(initializeLog); }
  const serverLog = fs.openSync(path.join(output,'server.log'),'w');
  const child = spawn(path.join(binaries,'mariadbd.exe'),['--defaults-file='+path.join(data,'my.ini'),'--bind-address=127.0.0.1','--port='+port,'--console'],
                      {windowsHide:true,stdio:['ignore',serverLog,serverLog]});
  let startupError, admin;
  child.on('error', error => {startupError=error;});
  const config = {host:'127.0.0.1',port,user:'root',password,connectTimeout:1000};
  try {
    const deadline = Date.now()+40000;
    while (Date.now()<deadline) {
      try {admin=await mysql.createConnection(config);break;}
      catch {
        if(startupError || child.exitCode !== null) throw new Error('Isolated MariaDB stopped during startup; inspect server.log');
        await delay(150);
      }
    }
    if (!admin) throw new Error('Isolated MariaDB startup timed out');
    const [[version]] = await admin.query('SELECT VERSION() AS version');
    console.log('Isolated Node-only MariaDB tests:',version.version);
    const {runIntegration} = require('./mariadb_node_spec');
    await runIntegration({mysql,config,admin,output});
  } finally {
    if(admin) {
      try {await admin.query('SHUTDOWN');} catch {}
      try {await admin.end();} catch {}
    }
    if(!await waitExit(child,15000)) {
      child.kill();
      if(!await waitExit(child,10000)) throw new Error('Could not stop owned test process');
    }
    fs.closeSync(serverLog);
    console.log('Isolated server stopped. Test artifacts:',path.relative(root,output));
  }
}

main().catch(error => {console.error('Node MariaDB test failure:',error.stack);process.exitCode=1;});
