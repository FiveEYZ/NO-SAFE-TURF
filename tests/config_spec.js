'use strict';
const assert=require('node:assert/strict');
const {connectionConfig,safeError}=require('../resource/server/storage/config');
const password='test/@:#%" space';
const cfg=connectionConfig('mysql://user:'+encodeURIComponent(password)+'@192.168.1.5:3306/txadmin_random?charset=utf8mb4');
assert.equal(cfg.password,password);assert.equal(cfg.database,'txadmin_random');assert.equal(cfg.host,'192.168.1.5');
assert.equal(cfg.multipleStatements,false);assert.equal(cfg.port,3306);
for(const rawPassword of ['example/with/slash', 'example@with:hash#question?', 'literal%value']) {
  const raw=connectionConfig('mysql://user:'+rawPassword+'@192.168.1.5:3306/test?charset=utf8mb4');
  assert.equal(raw.password,rawPassword);
  assert.equal(raw.host,'192.168.1.5');assert.equal(raw.database,'test');
}
assert.equal(connectionConfig('mysql://root@localhost/test').password,'');
assert.equal(connectionConfig('mysql://u:p@[::1]:3307/test').host,'::1');
for(const value of ['https://u:p@host/db','mysql://u:p@host/','mysql://u:p@host/db?multipleStatements=true','mysql://u:p@host/db#x'])assert.throws(()=>connectionConfig(value));
assert(!safeError(new Error(password)).includes(password));
console.log('PASS: txAdmin database URL, escaped password, empty password, IPv6 and rejected unsafe options');
