"""Loopback-only storage API with SQLite and MariaDB backends."""
from __future__ import annotations

import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import sqlite3
import threading
import time
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parent
TABLES = ('players', 'gangs', 'territories', 'robberies', 'hideouts', 'drops', 'alerts')


def empty_state(season=1):
    return {**{name: {} for name in TABLES}, 'season': season}


class Conflict(Exception):
    pass


class Schedule:
    def __init__(self, weekday=6, hour=4, minute=0):
        if not (0 <= weekday <= 6 and 0 <= hour <= 23 and 0 <= minute <= 59):
            raise ValueError('Invalid weekly schedule')
        self.weekday, self.hour, self.minute = weekday, hour, minute
        self.zone = ZoneInfo('Europe/Stockholm')

    def next_after(self, timestamp):
        local = datetime.fromtimestamp(timestamp, self.zone)
        for offset in range(9):
            date = local.date() + timedelta(days=offset)
            if date.weekday() != self.weekday:
                continue
            # fold=0 selects the FIRST occurrence during autumn ambiguity.
            candidate = datetime(date.year, date.month, date.day, self.hour,
                                 self.minute, tzinfo=self.zone, fold=0)
            # Spring's nonexistent local time moves forward by the DST gap.
            epoch = int(candidate.timestamp())
            if epoch > timestamp:
                return epoch
        raise RuntimeError('Cannot calculate next wipe')


class Store:
    def __init__(self, path, schedule=None, clock=time.time, failpoint=None):
        self.path = Path(path).resolve()
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.backups = self.path.parent / 'backups'
        self.backups.mkdir(exist_ok=True)
        self.schedule = schedule or Schedule()
        self.clock, self.failpoint = clock, failpoint
        self.lock = threading.RLock()
        self.db = sqlite3.connect(str(self.path), isolation_level=None, check_same_thread=False)
        self.db.executescript((ROOT / 'migrations/001_initial.sql').read_text())
        self.db.execute('INSERT OR IGNORE INTO world VALUES (1,0,?,?)',
                        (json.dumps(empty_state()), self.schedule.next_after(int(clock()))))

    def close(self):
        self.db.close()

    def envelope(self):
        revision, raw, due = self.db.execute('SELECT revision,state,next_wipe FROM world WHERE id=1').fetchone()
        return dict(state=json.loads(raw), revision=revision, nextWipe=due,
                    warningSeconds=max(0, due-int(self.clock())), maintenance=False)

    def _fail(self, stage):
        if self.failpoint:
            self.failpoint(stage)

    def _schedule(self):
        due = self.db.execute('SELECT next_wipe FROM world WHERE id=1').fetchone()[0]
        if int(self.clock()) >= due:
            self._wipe('weekly:' + str(due))

    def state(self):
        with self.lock:
            self._schedule()
            return self.envelope()

    def commit(self, revision, state, audit):
        if type(revision) is not int or not isinstance(state, dict):
            raise ValueError('Invalid commit')
        for name in TABLES:
            # Lua cjson encodes empty tables as arrays. Canonicalize empty maps.
            if state.get(name) == []:
                state[name] = {}
            if not isinstance(state.get(name), dict):
                raise ValueError('Invalid state map: '+name)
        if type(state.get('season')) is not int:
            raise ValueError('Invalid season')
        if not isinstance(audit, dict):
            raise ValueError('Invalid audit')
        action, actor = str(audit.get('action',''))[:80], str(audit.get('actor',''))[:100]
        encoded = json.dumps(state, allow_nan=False, separators=(',', ':'))
        if len(encoded) > 4_000_000:
            raise ValueError('State too large')
        with self.lock:
            self._schedule()
            self.db.execute('BEGIN IMMEDIATE')
            try:
                current = self.envelope()
                if current['revision'] != revision:
                    raise Conflict('Stale revision; reload /state')
                if current['state']['season'] != state['season']:
                    raise ValueError('Season can only be changed by wipe')
                self.db.execute('UPDATE world SET revision=revision+1,state=? WHERE id=1', (encoded,))
                self.db.execute('INSERT INTO audit(at,action,actor,revision) VALUES(?,?,?,?)',
                                (int(self.clock()), action, actor, revision+1))
                self.db.execute('COMMIT')
            except BaseException:
                if self.db.in_transaction:
                    self.db.execute('ROLLBACK')
                raise
            return self.envelope()

    def _backup(self, key):
        revision = self.db.execute('SELECT revision FROM world WHERE id=1').fetchone()[0]
        destination = self.backups / ('prewipe-' + hashlib.sha256(key.encode()).hexdigest()[:24] + '-r' + str(revision) + '.sqlite3')
        # Retrying a manual wipe after intervening gameplay needs a fresh snapshot.
        # Keep each revision immutable instead of overwriting an earlier attempt.
        if not destination.exists():
            temporary = destination.with_suffix('.partial')
            target = sqlite3.connect(str(temporary))
            try:
                self.db.backup(target)
                if target.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                    raise RuntimeError('Backup integrity failed')
            finally:
                target.close()
            os.replace(temporary, destination)
        return destination

    def _wipe(self, key):
        if self.db.execute('SELECT 1 FROM wipes WHERE key=?', (key,)).fetchone():
            return {**self.envelope(), 'alreadyDone': True}
        snapshot = self.envelope()
        backup = self._backup(key)
        self._fail('after_backup')
        self.db.execute('BEGIN IMMEDIATE')
        try:
            old = snapshot['state']
            rankings = sorted([{'gang': gid, 'name': g.get('name',gid), 'score': g.get('score',0)}
                               for gid,g in old['gangs'].items()], key=lambda g: -g['score'])
            now = int(self.clock())
            self.db.execute('INSERT INTO season_history VALUES(?,?,?)',
                            (old['season'], now, json.dumps(rankings)))
            self.db.execute('UPDATE world SET state=?,revision=revision+1,next_wipe=? WHERE id=1',
                            (json.dumps(empty_state(old['season']+1)), self.schedule.next_after(now)))
            self.db.execute('INSERT INTO wipes VALUES(?,?,?,?)', (key,now,old['season'],str(backup)))
            self.db.execute('INSERT INTO audit(at,action,actor,revision) VALUES(?,?,?,?)',
                            (now,'wipe','console/scheduler',snapshot['revision']+1))
            self._fail('before_commit')
            self.db.execute('COMMIT')
            self._fail('after_commit')
        except BaseException:
            if self.db.in_transaction:
                self.db.execute('ROLLBACK')
            raise
        return {**self.envelope(), 'alreadyDone': False, 'backup': str(backup)}

    def wipe(self, key, dry_run=False):
        if not isinstance(key,str) or not 1 <= len(key) <= 100:
            raise ValueError('Wipe key required (1–100 characters)')
        with self.lock:
            if dry_run:
                return {**self.envelope(), 'dryRun': True, 'key': key,
                        'alreadyDone': bool(self.db.execute('SELECT 1 FROM wipes WHERE key=?',(key,)).fetchone())}
            return self._wipe(key)


def restore(backup, destination, reschedule=None, now=None):
    """Restore to a NEW file only: caller switches paths after stopping both services."""
    source, target = Path(backup).resolve(), Path(destination).resolve()
    if target.exists() or source == target:
        raise ValueError('Restore destination must not exist')
    original = sqlite3.connect(source.as_uri()+'?mode=ro', uri=True)
    try:
        if original.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
            raise ValueError('Backup failed integrity check')
        original.execute('SELECT state FROM world').fetchone()
        target.parent.mkdir(parents=True,exist_ok=True)
        recovered = sqlite3.connect(str(target))
        try:
            original.backup(recovered)
            if reschedule is not None:
                timestamp = int(time.time() if now is None else now)
                with recovered:
                    recovered.execute('UPDATE world SET next_wipe=?,revision=revision+1 WHERE id=1',
                                      (reschedule.next_after(timestamp),))
                    revision = recovered.execute('SELECT revision FROM world WHERE id=1').fetchone()[0]
                    recovered.execute('INSERT INTO audit(at,action,actor,revision) VALUES(?,?,?,?)',
                                      (timestamp, 'restore_reschedule', 'offline-admin', revision))
        finally:
            recovered.close()
    finally:
        original.close()


def handler_for(store, token):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass  # Do not emit headers, tokens, identifiers or arbitrary request paths.

        def reply(self, status, body):
            payload=json.dumps(body,ensure_ascii=False).encode()
            self.send_response(status)
            self.send_header('Content-Type','application/json; charset=utf-8')
            self.send_header('Content-Length',str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def authorized(self):
            return hmac.compare_digest(self.headers.get('Authorization',''), 'Bearer '+token)

        def do_GET(self):
            if not self.authorized():
                return self.reply(401, {'error':'Unauthorized'})
            try:
                if self.path == '/health':
                    return self.reply(200, {'ok':True,'schema':1})
                if self.path == '/state':
                    return self.reply(200, store.state())
                self.reply(404, {'error':'Not found'})
            except Exception:
                self.reply(503, {'error':'Store unavailable; mutations stopped'})

        def do_POST(self):
            if not self.authorized():
                return self.reply(401, {'error':'Unauthorized'})
            try:
                length=int(self.headers.get('Content-Length','0'))
                if not 0 < length <= 4_500_000:
                    return self.reply(413, {'error':'Invalid body size'})
                body=json.loads(self.rfile.read(length))
                if self.path == '/commit':
                    result=store.commit(body['revision'],body['state'],body.get('audit',{}))
                elif self.path == '/wipe':
                    if type(body.get('dryRun',False)) is not bool:
                        raise ValueError('dryRun must be boolean')
                    result=store.wipe(body['key'],body.get('dryRun',False))
                else:
                    return self.reply(404, {'error':'Not found'})
                self.reply(200,result)
            except Conflict as exc:
                self.reply(409, {'error':str(exc)})
            except (ValueError,KeyError,TypeError):
                self.reply(400, {'error':'Invalid request'})
            except Exception:
                self.reply(503, {'error':'Store unavailable; reload state before retry'})
    return Handler


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--backend',choices=('sqlite','mariadb'),default=os.getenv('NST_BACKEND','sqlite'))
    parser.add_argument('--db',default=os.getenv('NST_DB','data/nst.sqlite3'))
    parser.add_argument('--port',type=int,default=8787)
    parser.add_argument('--weekday',type=int,default=6,help='Monday=0')
    parser.add_argument('--hour',type=int,default=4)
    parser.add_argument('--minute',type=int,default=0)
    parser.add_argument('--restore',metavar='BACKUP',help='Restore into a new SQLite file or an empty initialized MariaDB database, then exit')
    parser.add_argument('--reschedule-on-restore',action='store_true',help='Explicitly move restored deadline to next future weekly slot')
    parser.add_argument('--init-schema',action='store_true',help='Explicitly initialize MariaDB tables and exit')
    parser.add_argument('--export-backup',metavar='ID',help='Export a MariaDB pre-wipe backup and exit')
    parser.add_argument('--output',metavar='FILE',help='New file for --export-backup')
    args=parser.parse_args()
    schedule=Schedule(args.weekday,args.hour,args.minute)
    if sum(bool(value) for value in (args.init_schema,args.restore,args.export_backup))>1:
        parser.error('Choose only one offline operation')
    if args.reschedule_on_restore and not args.restore:
        parser.error('--reschedule-on-restore requires --restore')
    if args.output and not args.export_backup:
        parser.error('--output requires --export-backup')
    if args.backend=='mariadb':
        # Import this module by its package name so Conflict has one identity even
        # when the command is started with python -m service.server.
        from service.mariadb_store import MariaDBStore
        from service.server import Conflict as MariaDBConflict
        global Conflict
        Conflict=MariaDBConflict
        try:
            store=MariaDBStore.from_env(schedule=schedule,initialize=args.init_schema)
            if args.init_schema:
                store.close(); print('MariaDB schema initialized; no game server started.'); return
            if args.export_backup:
                if not args.output:
                    parser.error('--export-backup requires --output')
                store.export_backup(args.export_backup,args.output)
                store.close(); print('Backup exported to a new file.'); return
            if args.restore:
                store.restore_file(args.restore,reschedule=args.reschedule_on_restore)
                store.close(); print('Backup restored into the empty destination database.'); return
        except Exception as exc:
            # Driver errors may include account/host details. Do not print them.
            parser.exit(1,'MariaDB startup/operation failed ('+type(exc).__name__+'). Check private configuration, schema, and connectivity.\n')
    else:
        if args.init_schema or args.export_backup:
            parser.error('This offline operation requires --backend mariadb')
        store=None
    if args.restore:
        restore(args.restore,args.db,reschedule=schedule if args.reschedule_on_restore else None)
        print('Restored backup to new database; no server started.')
        return
    token=os.getenv('NST_TOKEN','')
    if len(token)<32:
        parser.error('Set NST_TOKEN to a random secret of at least 32 characters')
    if store is None:
        store=Store(args.db,schedule)
    server=ThreadingHTTPServer(('127.0.0.1',args.port),handler_for(store,token))
    print(f'NO SAFE TURF {args.backend} store listening on 127.0.0.1:{args.port}')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
        store.close()


if __name__ == '__main__':
    main()
