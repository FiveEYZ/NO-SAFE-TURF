'use strict';

// Server-only MariaDB storage. No credentials, FiveM natives or network events here.
const crypto = require('node:crypto');
const TABLES = Object.freeze(['players', 'gangs', 'territories', 'robberies', 'hideouts', 'drops', 'alerts']);
const PERSISTENT = Object.freeze({
  accounts: ['identifier', 'admin', 'settings'],
  bans: ['identifier', 'reason', 'expires_at'],
  settings: ['setting_key', 'value'],
  season_history: ['season', 'ended_at', 'leaderboard'],
  wipes: ['wipe_key', 'previous_season', 'completed_at', 'backup_id'],
  audit: ['id', 'at', 'action', 'actor', 'revision'],
});
const BACKUP_COLUMNS = ['backup_id', 'created_at', 'revision', 'payload', 'sha256'];
const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const record = value => value !== null && typeof value === 'object' && !Array.isArray(value);
const digest = text => crypto.createHash('sha256').update(text, 'utf8').digest('hex');

class Conflict extends Error {
  constructor(message = 'Stale revision; reload state') { super(message); this.name = 'Conflict'; this.code = 'CONFLICT'; }
}
class ValidationError extends Error {
  constructor(message) { super(message); this.name = 'ValidationError'; this.code = 'VALIDATION'; }
}
function check(ok, message) { if (!ok) throw new ValidationError(message); }
function integer(value, label, minimum = 0) {
  // mysql2 may return BIGINT columns as decimal strings. Never round them silently.
  const number = typeof value === 'string' && /^-?\d+$/.test(value) ? Number(value) : value;
  check(Number.isSafeInteger(number) && number >= minimum, 'Invalid ' + label);
  return number;
}
function identifier(value, maximum = 128) {
  check(typeof value === 'string' && [...value].length >= 1 && [...value].length <= maximum &&
    value === value.trimEnd() && !value.includes('\0'), 'Invalid identifier');
  return value;
}
function encode(value) {
  const seen = new Set();
  function serialize(item) {
    if (item === null || typeof item === 'string' || typeof item === 'boolean') return JSON.stringify(item);
    if (typeof item === 'number') { check(Number.isFinite(item), 'Non-finite JSON number'); return JSON.stringify(item); }
    check(item && typeof item === 'object' && !seen.has(item), 'Invalid or cyclic JSON data');
    seen.add(item);
    let result;
    if (Array.isArray(item)) result = '[' + item.map(serialize).join(',') + ']';
    else {
      check(Object.getPrototypeOf(item) === Object.prototype || Object.getPrototypeOf(item) === null, 'JSON object required');
      result = '{' + Object.keys(item).sort().map(key => JSON.stringify(key) + ':' + serialize(item[key])).join(',') + '}';
    }
    seen.delete(item);
    return result;
  }
  return serialize(value);
}
function emptyState(season = 1) { return Object.assign(Object.fromEntries(TABLES.map(name => [name, {}])), {season}); }
function normalize(input) {
  check(record(input) && Number.isSafeInteger(input.season) && input.season >= 1, 'Invalid season state');
  const encoded = encode(input);
  check(Buffer.byteLength(encoded, 'utf8') <= 4000000, 'State too large');
  const state = JSON.parse(encoded);
  for (const name of TABLES) {
    if (Array.isArray(state[name]) && state[name].length === 0) state[name] = {};
    check(record(state[name]), 'Invalid state collection');
    for (const [key, entity] of Object.entries(state[name])) {
      identifier(key); check(record(entity), 'Invalid entity');
      if (name === 'players' || name === 'gangs') {
        if (!own(entity, 'items') || (Array.isArray(entity.items) && entity.items.length === 0)) entity.items = {};
        check(record(entity.items), 'Invalid inventory');
        for (const [item, quantity] of Object.entries(entity.items)) {
          identifier(item); check(Number.isSafeInteger(quantity) && quantity >= 0, 'Invalid item quantity');
        }
      }
    }
  }
  return state;
}
function extraOf(state) { return Object.fromEntries(Object.entries(state).filter(([key]) => key !== 'season' && !TABLES.includes(key))); }
function entityPayload(entity, name) {
  return Object.fromEntries(Object.entries(entity).filter(([key]) => key !== 'items' || (name !== 'players' && name !== 'gangs')));
}
function parseObject(text, label) {
  let value;
  try { value = typeof text === 'string' ? JSON.parse(text) : text; }
  catch { throw new ValidationError('Invalid stored ' + label); }
  check(record(value), 'Invalid stored ' + label);
  return value;
}

class MariaDBStore {
  constructor({pool, schedule, clock = () => Math.floor(Date.now() / 1000), failpoint = null, schema = null}) {
    check(pool && typeof pool.getConnection === 'function', 'A MariaDB connection pool is required');
    check(schedule && typeof schedule.nextAfter === 'function', 'A wipe schedule is required');
    this.pool = pool; this.schedule = schedule; this.clock = clock; this.failpoint = failpoint; this.schema = schema;
  }
  now() { return integer(this.clock(), 'clock'); }
  nextWipe(now) { const due = integer(this.schedule.nextAfter(now), 'wipe deadline'); check(due > now, 'Wipe deadline must be in the future'); return due; }
  async fail(stage) { if (this.failpoint) await this.failpoint(stage); }
  async initialize({createSchema = false, schema = this.schema, schemaSql, seedMissingMeta = false} = {}) {
    const connection = await this.pool.getConnection();
    try {
      const [versions] = await connection.query('SELECT VERSION() AS version');
      const version = String(versions[0]?.version || '');
      const match = version.replace(/^5\.5\.5-/, '').match(/^(\d+)\.(\d+)\./);
      check(version.includes('MariaDB') && match && (Number(match[1]) > 10 || (Number(match[1]) === 10 && Number(match[2]) >= 11)),
        'MariaDB 10.11 or newer is required');
      this.version = version;
      if (createSchema) {
        const sql = schemaSql ?? schema;
        check(typeof sql === 'string' && sql.length > 0, 'Schema SQL is required for initialization');
        // This is the bundled, reviewed v1 migration, not arbitrary client input.
        const statements = sql.split(/\r?\n/).filter(line => !line.trimStart().startsWith('--')).join('\n').split(';');
        for (const statement of statements) if (statement.trim()) await connection.query(statement);
        await connection.query("INSERT IGNORE INTO nst_meta(id,revision,season,next_wipe,extra) VALUES(1,0,1,?,'{}')", [this.nextWipe(this.now())]);
      }
      const [migrations] = await connection.query('SELECT version FROM nst_schema_migrations ORDER BY version');
      check(migrations.length === 1 && Number(migrations[0].version) === 1, 'Unsupported MariaDB schema version');
      let [meta] = await connection.query('SELECT id FROM nst_meta WHERE id=1');
      if (!meta.length && seedMissingMeta) {
        // Recipe imports the schema; only an empty installation may get its first season.
        for (const name of [...TABLES, 'player_items', 'gang_items', ...Object.keys(PERSISTENT), 'backups']) {
          const [[row]] = await connection.query('SELECT COUNT(*) AS n FROM nst_'+name);
          check(Number(row.n)===0, 'Refusing to initialize an occupied database');
        }
        await connection.query("INSERT IGNORE INTO nst_meta(id,revision,season,next_wipe,extra) VALUES(1,0,1,?,'{}')", [this.nextWipe(this.now())]);
        [meta] = await connection.query('SELECT id FROM nst_meta WHERE id=1');
      }
      check(meta.length === 1, 'Schema is not initialized; initialize it explicitly');
      await connection.commit();
      return {version, schema: 1};
    } catch (error) {
      try { await connection.rollback(); } catch { /* Preserve the original error. */ }
      throw error;
    } finally { connection.release(); }
  }
  async close() { await this.pool.end(); }
  async transaction(operation) {
    const connection = await this.pool.getConnection();
    try {
      await connection.beginTransaction();
      const [rows] = await connection.query('SELECT * FROM nst_meta WHERE id=1 FOR UPDATE');
      check(rows.length === 1, 'Missing season metadata');
      const meta = {...rows[0], revision: integer(rows[0].revision, 'revision'), season: integer(rows[0].season, 'season', 1), next_wipe: integer(rows[0].next_wipe, 'wipe deadline')};
      const result = await operation(connection, meta);
      await this.fail('before_commit');
      await connection.commit();
      await this.fail('after_commit');
      return result;
    } catch (error) {
      try { await connection.rollback(); } catch { /* Unknown commit outcomes must be reconciled by reloading. */ }
      throw error;
    } finally { connection.release(); }
  }
  async read(connection, meta) {
    const state = parseObject(meta.extra, 'metadata');
    state.season = meta.season;
    for (const name of TABLES) {
      const [rows] = await connection.query(`SELECT entity_id,payload FROM nst_${name}`);
      state[name] = Object.fromEntries(rows.map(row => [row.entity_id, parseObject(row.payload, 'entity')]));
    }
    for (const [owners, table] of [['players', 'player_items'], ['gangs', 'gang_items']]) {
      for (const entity of Object.values(state[owners])) entity.items = Object.create(null);
      const [rows] = await connection.query(`SELECT owner_id,item_id,quantity FROM nst_${table}`);
      for (const row of rows) {
        check(own(state[owners], row.owner_id), 'Orphan inventory row');
        state[owners][row.owner_id].items[row.item_id] = integer(row.quantity, 'item quantity');
      }
    }
    return {state, revision: meta.revision, nextWipe: meta.next_wipe, warningSeconds: Math.max(0, meta.next_wipe - this.now()), maintenance: false};
  }
  async write(connection, old, next) {
    for (const name of TABLES) {
      const previous = old[name], current = next[name];
      for (const key of Object.keys(previous)) if (!own(current, key)) await connection.query(`DELETE FROM nst_${name} WHERE entity_id=?`, [key]);
      for (const [key, entity] of Object.entries(current)) {
        const before = own(previous, key) ? previous[key] : {};
        const payload = entityPayload(entity, name);
        if (!own(previous, key) || encode(payload) !== encode(entityPayload(before, name))) {
          await connection.query(`INSERT INTO nst_${name}(entity_id,payload) VALUES(?,?) ON DUPLICATE KEY UPDATE payload=VALUES(payload)`, [key, encode(payload)]);
        }
        if (name === 'players' || name === 'gangs') {
          const table = name === 'players' ? 'player_items' : 'gang_items';
          const oldItems = before.items || {}, newItems = entity.items || {};
          for (const item of Object.keys(oldItems)) if (!own(newItems, item)) await connection.query(`DELETE FROM nst_${table} WHERE owner_id=? AND item_id=?`, [key, item]);
          for (const [item, quantity] of Object.entries(newItems)) if (!own(oldItems, item) || oldItems[item] !== quantity) {
            await connection.query(`INSERT INTO nst_${table}(owner_id,item_id,quantity) VALUES(?,?,?) ON DUPLICATE KEY UPDATE quantity=VALUES(quantity)`, [key, item, quantity]);
          }
        }
      }
    }
    await connection.query('UPDATE nst_meta SET revision=revision+1,season=?,extra=? WHERE id=1', [next.season, encode(extraOf(next))]);
  }
  async audit(connection, action, actor, revision) {
    await connection.query('INSERT INTO nst_audit(at,action,actor,revision) VALUES(?,?,?,?)',
      [this.now(), String(action).slice(0, 80), String(actor).slice(0, 128), revision]);
  }
  async wipeLocked(connection, meta, key) {
    const [existing] = await connection.query('SELECT backup_id FROM nst_wipes WHERE wipe_key=?', [key]);
    if (existing.length) return {...await this.read(connection, meta), alreadyDone: true, backup: existing[0].backup_id};
    check(meta.revision < Number.MAX_SAFE_INTEGER && meta.season < Number.MAX_SAFE_INTEGER, 'Season counters exhausted');
    const snapshot = await this.read(connection, meta), tables = {};
    for (const [name, columns] of Object.entries(PERSISTENT)) {
      const [rows] = await connection.query(`SELECT ${columns.join(',')} FROM nst_${name}`);
      tables[name] = rows.map(row => Object.fromEntries(columns.map(column => [column, row[column]])));
    }
    const payload = encode({format: 1, envelope: snapshot, tables});
    const backupId = digest(key + ':' + meta.revision);
    await connection.query('INSERT INTO nst_backups(backup_id,created_at,revision,payload,sha256) VALUES(?,?,?,?,?)',
      [backupId, this.now(), meta.revision, payload, digest(payload)]);
    await this.fail('after_backup');
    const old = snapshot.state;
    const rankings = Object.entries(old.gangs).map(([gang, value]) => ({gang, name: value.name ?? gang, score: value.score ?? 0})).sort((a, b) => b.score - a.score);
    await connection.query('INSERT INTO nst_season_history(season,ended_at,leaderboard) VALUES(?,?,?)', [old.season, this.now(), encode(rankings)]);
    await this.write(connection, old, emptyState(old.season + 1));
    const due = this.nextWipe(this.now());
    await connection.query('UPDATE nst_meta SET next_wipe=? WHERE id=1', [due]);
    await connection.query('INSERT INTO nst_wipes(wipe_key,previous_season,completed_at,backup_id) VALUES(?,?,?,?)', [key, old.season, this.now(), backupId]);
    await this.audit(connection, 'wipe', 'console/scheduler', meta.revision + 1);
    return {...await this.read(connection, {...meta, revision: meta.revision + 1, season: old.season + 1, next_wipe: due, extra: '{}'}), alreadyDone: false, backup: backupId};
  }
  async state() {
    return this.transaction((connection, meta) => this.now() >= meta.next_wipe ? this.wipeLocked(connection, meta, 'weekly:' + meta.next_wipe) : this.read(connection, meta));
  }
  async commit(revision, state, audit) {
    check(Number.isSafeInteger(revision) && revision >= 0 && revision < Number.MAX_SAFE_INTEGER && record(audit), 'Invalid commit');
    const next = normalize(state);
    await this.state(); // A due wipe commits before a stale gameplay revision is rejected.
    return this.transaction(async (connection, meta) => {
      if (meta.revision !== revision || this.now() >= meta.next_wipe) throw new Conflict();
      const old = (await this.read(connection, meta)).state;
      check(old.season === next.season, 'Season can only be changed by wipe');
      await this.write(connection, old, next);
      await this.audit(connection, audit.action ?? '', audit.actor ?? '', revision + 1);
      return this.read(connection, {...meta, revision: revision + 1, extra: encode(extraOf(next))});
    });
  }
  async wipe(key, dryRun = false) {
    identifier(key, 100); check(typeof dryRun === 'boolean', 'dryRun must be boolean');
    return this.transaction(async (connection, meta) => {
      if (!dryRun) return this.wipeLocked(connection, meta, key);
      const [existing] = await connection.query('SELECT 1 FROM nst_wipes WHERE wipe_key=?', [key]);
      return {...await this.read(connection, meta), dryRun: true, key, alreadyDone: existing.length > 0};
    });
  }
  async exportBackup(backupId) {
    identifier(backupId);
    return this.transaction(async (connection) => {
      const [roots] = await connection.query('SELECT * FROM nst_backups WHERE backup_id=?', [backupId]);
      check(roots.length === 1, 'Backup not found');
      const root = Object.fromEntries(BACKUP_COLUMNS.map(key => [key, roots[0][key]]));
      check(digest(root.payload) === root.sha256, 'Stored backup integrity check failed');
      const document = parseObject(root.payload, 'backup');
      check(document.format === 1 && Array.isArray(document.tables?.wipes), 'Unsupported backup payload');
      const references = new Set(document.tables.wipes.map(row => row.backup_id));
      const backups = [root];
      references.delete(backupId);
      for (const key of [...references].sort()) {
        const [rows] = await connection.query('SELECT * FROM nst_backups WHERE backup_id=?', [key]);
        check(rows.length === 1 && digest(rows[0].payload) === rows[0].sha256, 'Referenced backup missing or corrupt');
        backups.push(Object.fromEntries(BACKUP_COLUMNS.map(column => [column, rows[0][column]])));
      }
      return {format: 1, root: backupId, backups};
    });
  }
  async restoreArchive(archive, {reschedule = false} = {}) {
    check(record(archive) && archive.format === 1 && Array.isArray(archive.backups) && typeof reschedule === 'boolean', 'Invalid backup archive');
    const backups = new Map();
    for (const row of archive.backups) {
      check(record(row) && typeof row.payload === 'string' && digest(row.payload) === row.sha256 && !backups.has(row.backup_id), 'Backup integrity check failed');
      identifier(row.backup_id); integer(row.created_at, 'backup timestamp'); integer(row.revision, 'backup revision');
      backups.set(row.backup_id, row);
    }
    check(backups.has(archive.root), 'Root backup missing');
    const snapshot = parseObject(backups.get(archive.root).payload, 'backup');
    check(snapshot.format === 1 && record(snapshot.tables) && encode(Object.keys(snapshot.tables).sort()) === encode(Object.keys(PERSISTENT).sort()), 'Unsupported backup payload');
    check(record(snapshot.envelope), 'Invalid backup envelope');
    const restored = normalize(snapshot.envelope.state);
    const revision = integer(snapshot.envelope.revision, 'backup revision') + 1;
    check(Number.isSafeInteger(revision), 'Backup revision exhausted');
    const archivedDue = integer(snapshot.envelope.nextWipe, 'backup deadline');
    for (const [name, columns] of Object.entries(PERSISTENT)) {
      check(Array.isArray(snapshot.tables[name]), 'Invalid backup table');
      for (const row of snapshot.tables[name]) check(record(row) && columns.every(column => own(row, column)), 'Invalid backup row');
    }
    for (const row of snapshot.tables.wipes) check(backups.has(row.backup_id), 'Referenced backup missing');
    return this.transaction(async (connection, meta) => {
      check(meta.revision === 0 && meta.season === 1, 'Restore requires a fresh initialized database');
      for (const name of [...TABLES, ...Object.keys(PERSISTENT), 'backups']) {
        const [rows] = await connection.query(`SELECT COUNT(*) AS n FROM nst_${name}`);
        check(Number(rows[0].n) === 0, 'Restore destination is not empty');
      }
      await this.write(connection, emptyState(), restored);
      for (const row of backups.values()) await connection.query('INSERT INTO nst_backups(backup_id,created_at,revision,payload,sha256) VALUES(?,?,?,?,?)', BACKUP_COLUMNS.map(key => row[key]));
      for (const [name, columns] of Object.entries(PERSISTENT)) {
        for (const row of snapshot.tables[name]) await connection.query(`INSERT INTO nst_${name}(${columns.join(',')}) VALUES(${columns.map(() => '?').join(',')})`, columns.map(column => row[column]));
      }
      const due = reschedule ? this.nextWipe(this.now()) : archivedDue;
      await connection.query('UPDATE nst_meta SET revision=?,next_wipe=? WHERE id=1', [revision, due]);
      await this.audit(connection, reschedule ? 'restore_reschedule' : 'restore', 'offline-admin', revision);
      return this.read(connection, {...meta, revision, season: restored.season, next_wipe: due, extra: encode(extraOf(restored))});
    });
  }
}

module.exports = {MariaDBStore, Conflict, ValidationError, normalize, encode, emptyState, TABLES, PERSISTENT};
