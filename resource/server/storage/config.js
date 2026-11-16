'use strict';
const fs = require('node:fs');
const path = require('node:path');
const L=require('./locale_en');

function readConfig(filename) {
  return validateConfig(JSON.parse(fs.readFileSync(filename, 'utf8').replace(/^\uFEFF/, '')),path.dirname(filename));
}
function connectionConfig(value) {
  const url = new URL(value);
  if(url.protocol !== 'mysql:' || url.hash || [...url.searchParams].some(([key,value])=>key!=='charset'||value!=='utf8mb4')) throw new Error('Invalid database URL');
  return validateConfig({host:url.hostname.replace(/^\[|\]$/g,''),port:Number(url.port||3306),
    user:decodeURIComponent(url.username),password:decodeURIComponent(url.password),database:decodeURIComponent(url.pathname.slice(1))});
}
function validateConfig(raw, directory='.') {
  const config = {};
  for (const key of ['host', 'user', 'password', 'database']) {
    if (typeof raw[key] !== 'string' || (key!=='password' && !raw[key].length)) throw new Error('Private database configuration is incomplete');
    config[key] = raw[key];
  }
  config.port = raw.port ?? 3306;
  if (!Number.isInteger(config.port) || config.port < 1 || config.port > 65535) throw new Error('Invalid database port');
  if (raw.sslCa) config.ssl = {
    ca: fs.readFileSync(path.resolve(directory, raw.sslCa), 'utf8'),
    rejectUnauthorized: true, verifyIdentity: true
  };
  return {...config, charset:'utf8mb4', connectionLimit:4, waitForConnections:true, queueLimit:32,
    connectTimeout:10000, supportBigNumbers:true, bigNumberStrings:true,
    multipleStatements:false, enableKeepAlive:true};
}

function safeError(error) {
  // Never return driver messages, SQL, connection strings or credentials.
  const code = typeof error?.code === 'string' && /^[A-Z0-9_]{1,50}$/.test(error.code) ? error.code : 'STORAGE_UNAVAILABLE';
  return L.failure.replace('{code}',code);
}

module.exports = {readConfig, connectionConfig, safeError};
