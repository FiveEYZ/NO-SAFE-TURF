"""Transactional MariaDB storage for the existing server-authoritative Lua API.

Rows are separated by entity and inventory item; only changed rows are written.
The global revision lock is intentional: gameplay still uses shared snapshots.
"""
from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import re
import threading
import time

from service.server import Conflict, Schedule, TABLES, empty_state

SCHEMA = Path(__file__).resolve().parents[1] / 'database/mariadb/001_initial.sql'
PERSISTENT = {
    'accounts': ('identifier', 'admin', 'settings'),
    'bans': ('identifier', 'reason', 'expires_at'),
    'settings': ('setting_key', 'value'),
    'season_history': ('season', 'ended_at', 'leaderboard'),
    'wipes': ('wipe_key', 'previous_season', 'completed_at', 'backup_id'),
    'audit': ('id', 'at', 'action', 'actor', 'revision'),
}


def encode(value):
    return json.dumps(value, ensure_ascii=False, allow_nan=False, sort_keys=True, separators=(',', ':'))


def identifier(value):
    if not isinstance(value, str) or not 1 <= len(value) <= 128 or value != value.rstrip() or '\x00' in value:
        raise ValueError('Invalid entity identifier')
    return value


def normalize(state):
    state = copy.deepcopy(state)
    if not isinstance(state, dict) or type(state.get('season')) is not int or not 1 <= state['season'] <= 2**53-1:
        raise ValueError('Invalid season state')
    for name in TABLES:
        if state.get(name) == []:
            state[name] = {}
        if not isinstance(state.get(name), dict):
            raise ValueError('Invalid state collection')
        for key, entity in state[name].items():
            identifier(key)
            if not isinstance(entity, dict):
                raise ValueError('Invalid entity')
            if name in ('players', 'gangs'):
                items = entity.setdefault('items', {})
                if items == []:
                    items = entity['items'] = {}
                if not isinstance(items, dict):
                    raise ValueError('Invalid inventory')
                for item, quantity in items.items():
                    identifier(item)
                    if type(quantity) is not int or not 0 <= quantity <= 2**53-1:
                        raise ValueError('Invalid item quantity')
    if len(encode(state).encode('utf-8')) > 4_000_000:
        raise ValueError('State too large')
    return state


class MariaDBStore:
    def __init__(self, config, schedule=None, clock=time.time, failpoint=None, initialize=False):
        import pymysql
        self.driver = pymysql
        self.config = dict(config)
        self.config.update(charset='utf8mb4', autocommit=False, cursorclass=pymysql.cursors.DictCursor,
                           connect_timeout=5, read_timeout=15, write_timeout=15)
        self.schedule = schedule or Schedule()
        self.clock, self.failpoint = clock, failpoint
        self.lock = threading.RLock()
        connection = self._connect()
        try:
            with connection.cursor() as cursor:
                cursor.execute('SELECT VERSION() AS version')
                version = cursor.fetchone()['version']
                match = re.search(r'(\d+)\.(\d+)\.', version)
                if 'MariaDB' not in version or not match or tuple(map(int, match.groups())) < (10, 11):
                    raise ValueError('MariaDB 10.11 or newer is required')
                self.version = version
                if initialize:
                    sql = '\n'.join(line for line in SCHEMA.read_text(encoding='utf-8').splitlines()
                                    if not line.lstrip().startswith('--'))
                    for statement in sql.split(';'):
                        if statement.strip():
                            cursor.execute(statement)
                    cursor.execute("INSERT IGNORE INTO nst_meta(id,revision,season,next_wipe,extra) VALUES(1,0,1,%s,'{}')",
                                   (self.schedule.next_after(int(clock())),))
                    connection.commit()
                cursor.execute('SELECT version FROM nst_schema_migrations ORDER BY version')
                if [r['version'] for r in cursor.fetchall()] != [1]:
                    raise ValueError('Unsupported MariaDB schema version')
                cursor.execute('SELECT id FROM nst_meta WHERE id=1')
                if cursor.fetchone() is None:
                    raise ValueError('Schema is not initialized; run --init-schema explicitly')
        finally:
            connection.close()

    @classmethod
    def from_env(cls, **kwargs):
        config = {}
        for env, field in [('NST_DB_HOST', 'host'), ('NST_DB_USER', 'user'),
                           ('NST_DB_PASSWORD', 'password'), ('NST_DB_NAME', 'database')]:
            value = os.getenv(env)
            if not value:
                raise ValueError('Required database environment variable missing: ' + env)
            config[field] = value
        config['port'] = int(os.getenv('NST_DB_PORT', '3306'))
        if not 1 <= config['port'] <= 65535:
            raise ValueError('Invalid database port')
        ca = os.getenv('NST_DB_SSL_CA')
        if ca:
            config.update(ssl_ca=ca, ssl_verify_cert=True, ssl_verify_identity=True)
        return cls(config, **kwargs)

    def _connect(self):
        return self.driver.connect(**self.config)

    def close(self):
        pass  # Connections are bounded to individual transactions, never replayed.

    def _fail(self, stage):
        if self.failpoint:
            self.failpoint(stage)

    def _transaction(self, operation):
        with self.lock:
            connection = self._connect()
            try:
                connection.begin()
                with connection.cursor() as cursor:
                    cursor.execute('SELECT * FROM nst_meta WHERE id=1 FOR UPDATE')
                    meta = cursor.fetchone()
                    if not meta:
                        raise RuntimeError('Missing season metadata')
                    result = operation(cursor, meta)
                self._fail('before_commit')
                connection.commit()
                self._fail('after_commit')
                return result
            except BaseException:
                try:
                    connection.rollback()
                except Exception:
                    pass
                raise
            finally:
                connection.close()

    def _read(self, cursor, meta):
        state = json.loads(meta['extra'])
        state['season'] = meta['season']
        for name in TABLES:
            cursor.execute(f'SELECT entity_id,payload FROM nst_{name}')
            state[name] = {r['entity_id']: json.loads(r['payload']) for r in cursor.fetchall()}
        for owners, table in [('players', 'player_items'), ('gangs', 'gang_items')]:
            for entity in state[owners].values():
                entity['items'] = {}
            cursor.execute(f'SELECT owner_id,item_id,quantity FROM nst_{table}')
            for row in cursor.fetchall():
                state[owners][row['owner_id']]['items'][row['item_id']] = row['quantity']
        return dict(state=state, revision=meta['revision'], nextWipe=meta['next_wipe'],
                    warningSeconds=max(0, meta['next_wipe'] - int(self.clock())), maintenance=False)

    def _write(self, cursor, old, new):
        for name in TABLES:
            previous, current = old[name], new[name]
            for key in previous.keys() - current.keys():
                cursor.execute(f'DELETE FROM nst_{name} WHERE entity_id=%s', (key,))
            for key, entity in current.items():
                payload = {k: v for k, v in entity.items() if k != 'items' or name not in ('players', 'gangs')}
                old_entity = previous.get(key, {})
                old_payload = {k: v for k, v in old_entity.items() if k != 'items' or name not in ('players', 'gangs')}
                if key not in previous or payload != old_payload:
                    cursor.execute(f'INSERT INTO nst_{name}(entity_id,payload) VALUES(%s,%s) ON DUPLICATE KEY UPDATE payload=VALUES(payload)',
                                   (key, encode(payload)))
                if name in ('players', 'gangs'):
                    table = 'player_items' if name == 'players' else 'gang_items'
                    before, after = old_entity.get('items', {}), entity.get('items', {})
                    for item in before.keys() - after.keys():
                        cursor.execute(f'DELETE FROM nst_{table} WHERE owner_id=%s AND item_id=%s', (key, item))
                    for item, quantity in after.items():
                        if item not in before or before[item] != quantity:
                            cursor.execute(f'INSERT INTO nst_{table}(owner_id,item_id,quantity) VALUES(%s,%s,%s) ON DUPLICATE KEY UPDATE quantity=VALUES(quantity)',
                                           (key, item, quantity))
        extra = {k: v for k, v in new.items() if k not in TABLES and k != 'season'}
        cursor.execute('UPDATE nst_meta SET revision=revision+1,season=%s,extra=%s WHERE id=1',
                       (new['season'], encode(extra)))

    def _audit(self, cursor, action, actor, revision):
        cursor.execute('INSERT INTO nst_audit(at,action,actor,revision) VALUES(%s,%s,%s,%s)',
                       (int(self.clock()), str(action)[:80], str(actor)[:128], revision))

    def _wipe(self, cursor, meta, key):
        cursor.execute('SELECT backup_id FROM nst_wipes WHERE wipe_key=%s', (key,))
        existing = cursor.fetchone()
        if existing:
            return {**self._read(cursor, meta), 'alreadyDone': True, 'backup': existing['backup_id']}
        snapshot = self._read(cursor, meta)
        tables = {}
        for name, columns in PERSISTENT.items():
            cursor.execute(f"SELECT {','.join(columns)} FROM nst_{name}")
            tables[name] = cursor.fetchall()
        payload = encode({'format': 1, 'envelope': snapshot, 'tables': tables})
        backup_id = hashlib.sha256((key + ':' + str(meta['revision'])).encode()).hexdigest()
        cursor.execute('INSERT INTO nst_backups(backup_id,created_at,revision,payload,sha256) VALUES(%s,%s,%s,%s,%s)',
                       (backup_id, int(self.clock()), meta['revision'], payload, hashlib.sha256(payload.encode()).hexdigest()))
        self._fail('after_backup')
        old = snapshot['state']
        rankings = sorted([{'gang': gid, 'name': g.get('name', gid), 'score': g.get('score', 0)}
                           for gid, g in old['gangs'].items()], key=lambda g: -g['score'])
        cursor.execute('INSERT INTO nst_season_history(season,ended_at,leaderboard) VALUES(%s,%s,%s)',
                       (old['season'], int(self.clock()), encode(rankings)))
        self._write(cursor, old, empty_state(old['season'] + 1))
        due = self.schedule.next_after(int(self.clock()))
        cursor.execute('UPDATE nst_meta SET next_wipe=%s WHERE id=1', (due,))
        cursor.execute('INSERT INTO nst_wipes(wipe_key,previous_season,completed_at,backup_id) VALUES(%s,%s,%s,%s)',
                       (key, old['season'], int(self.clock()), backup_id))
        self._audit(cursor, 'wipe', 'console/scheduler', meta['revision'] + 1)
        updated = dict(meta, revision=meta['revision'] + 1, season=old['season'] + 1, next_wipe=due, extra='{}')
        return {**self._read(cursor, updated), 'alreadyDone': False, 'backup': backup_id}

    def state(self):
        return self._transaction(lambda cursor, meta: self._wipe(cursor, meta, 'weekly:' + str(meta['next_wipe']))
                                 if int(self.clock()) >= meta['next_wipe'] else self._read(cursor, meta))

    def commit(self, revision, state, audit):
        if type(revision) is not int or revision < 0 or not isinstance(audit, dict):
            raise ValueError('Invalid commit')
        new = normalize(state)
        self.state()  # Persist any due wipe before rejecting a stale gameplay commit.
        def apply(cursor, meta):
            if meta['revision'] != revision or int(self.clock()) >= meta['next_wipe']:
                raise Conflict('Stale revision; reload /state')
            old = self._read(cursor, meta)['state']
            if old['season'] != new['season']:
                raise ValueError('Season can only be changed by wipe')
            self._write(cursor, old, new)
            self._audit(cursor, audit.get('action', ''), audit.get('actor', ''), revision + 1)
            extra = {k: v for k, v in new.items() if k not in TABLES and k != 'season'}
            return self._read(cursor, dict(meta, revision=revision + 1, extra=encode(extra)))
        return self._transaction(apply)

    def wipe(self, key, dry_run=False):
        if not isinstance(key, str) or not 1 <= len(key) <= 100 or key != key.rstrip() or '\x00' in key:
            raise ValueError('Wipe key required (1-100 characters, no trailing spaces)')
        def apply(cursor, meta):
            if not dry_run:
                return self._wipe(cursor, meta, key)
            cursor.execute('SELECT 1 FROM nst_wipes WHERE wipe_key=%s', (key,))
            already = cursor.fetchone() is not None
            return {**self._read(cursor, meta), 'dryRun': True, 'key': key, 'alreadyDone': already}
        return self._transaction(apply)

    def export_backup(self, backup_id, path):
        def export(cursor, _meta):
            cursor.execute('SELECT * FROM nst_backups WHERE backup_id=%s', (backup_id,))
            root = cursor.fetchone()
            if not root:
                raise ValueError('Backup not found')
            document = json.loads(root['payload'])
            ids = {row['backup_id'] for row in document['tables']['wipes']}
            backups = [root]
            for key in sorted(ids - {backup_id}):
                cursor.execute('SELECT * FROM nst_backups WHERE backup_id=%s', (key,))
                row = cursor.fetchone()
                if row is None:
                    raise ValueError('Referenced backup missing')
                backups.append(row)
            return {'format': 1, 'root': backup_id, 'backups': backups}
        archive = self._transaction(export)
        with Path(path).open('x', encoding='utf-8') as output:
            output.write(encode(archive))

    def restore_file(self, path, reschedule=False):
        archive = json.loads(Path(path).read_text(encoding='utf-8'))
        if archive.get('format') != 1 or not isinstance(archive.get('backups'), list):
            raise ValueError('Invalid backup archive')
        backups = {}
        for row in archive['backups']:
            if hashlib.sha256(row['payload'].encode()).hexdigest() != row['sha256'] or row['backup_id'] in backups:
                raise ValueError('Backup integrity check failed')
            backups[row['backup_id']] = row
        if archive.get('root') not in backups:
            raise ValueError('Root backup missing')
        snapshot = json.loads(backups[archive['root']]['payload'])
        if snapshot.get('format') != 1 or set(snapshot.get('tables', {})) != set(PERSISTENT):
            raise ValueError('Unsupported backup payload')
        restored = normalize(snapshot['envelope']['state'])
        def apply(cursor, meta):
            if meta['revision'] != 0 or meta['season'] != 1:
                raise ValueError('Restore requires a fresh initialized database')
            for name in (*TABLES, *PERSISTENT, 'backups'):
                cursor.execute(f'SELECT COUNT(*) AS n FROM nst_{name}')
                if cursor.fetchone()['n']:
                    raise ValueError('Restore destination is not empty')
            self._write(cursor, empty_state(), restored)
            for row in backups.values():
                cursor.execute('INSERT INTO nst_backups(backup_id,created_at,revision,payload,sha256) VALUES(%s,%s,%s,%s,%s)',
                               tuple(row[k] for k in ('backup_id', 'created_at', 'revision', 'payload', 'sha256')))
            for name, columns in PERSISTENT.items():
                for row in snapshot['tables'][name]:
                    cursor.execute(f"INSERT INTO nst_{name}({','.join(columns)}) VALUES({','.join(['%s'] * len(columns))})",
                                   tuple(row[k] for k in columns))
            due = self.schedule.next_after(int(self.clock())) if reschedule else snapshot['envelope']['nextWipe']
            revision = snapshot['envelope']['revision'] + 1
            cursor.execute('UPDATE nst_meta SET revision=%s,next_wipe=%s WHERE id=1', (revision, due))
            self._audit(cursor, 'restore_reschedule' if reschedule else 'restore', 'offline-admin', revision)
        self._transaction(apply)
