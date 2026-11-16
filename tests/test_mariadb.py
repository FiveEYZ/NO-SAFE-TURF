"""Real MariaDB contract tests. Run with tests/run_mariadb.py for isolation."""
import concurrent.futures
import copy
import json
import os
from pathlib import Path
import uuid
import unittest
import socket
import subprocess
import sys
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError

from service.server import Conflict, empty_state
from service.mariadb_store import MariaDBStore, normalize


class MariaDBValidationTests(unittest.TestCase):
    def test_normalize_maps_and_reject_invalid_inventory(self):
        state=empty_state()
        state['players']={'a':{'items':[],'cash':500}}
        self.assertEqual(normalize(state)['players']['a']['items'],{})
        for quantity in (-1,True,0.5,float('nan')):
            state['players']['a']['items']={'bat':quantity}
            with self.assertRaises(ValueError):
                normalize(state)
        state['players']={'ambiguous ': {'items':{}}}
        with self.assertRaises(ValueError):
            normalize(state)


@unittest.skipUnless(os.getenv('NST_ISOLATED_MARIADB_TEST')=='1', 'Run tests/run_mariadb.py to provision an isolated MariaDB server')
class MariaDBIntegrationTests(unittest.TestCase):
    def setUp(self):
        import pymysql
        self.config=dict(host='127.0.0.1',port=int(os.environ['NST_TEST_DB_PORT']),
                         user='root',password=os.environ['NST_TEST_DB_PASSWORD'])
        self.admin=pymysql.connect(**self.config,autocommit=True)
        self.name='nst_test_'+uuid.uuid4().hex
        with self.admin.cursor() as c:
            c.execute('CREATE DATABASE '+self.name+' CHARACTER SET utf8mb4 COLLATE utf8mb4_bin')
        self.config['database']=self.name
        self.now=1794672000
        self.store=MariaDBStore(self.config,initialize=True,clock=lambda:self.now)

    def tearDown(self):
        self.store.close()
        self.admin.close()
        # The isolated server's entire data directory is disposable. Do not issue
        # DROP DATABASE against credentials that might accidentally be reused.

    def seed(self):
        env=self.store.state()
        env['state']['players']={'a':{'cash':500,'items':{'stolen':6,'bat':1}},'b':{'cash':500,'items':{}}}
        env['state']['gangs']={'a':{'name':'Concrete','score':12,'bank':100,'items':{'stolen':8}}}
        return self.store.commit(env['revision'],env['state'],{'action':'seed','actor':'test'})

    def query(self,sql,args=()):
        conn=self.store._connect()
        try:
            with conn.cursor() as c:
                c.execute(sql,args)
                rows=c.fetchall()
            conn.commit()
            return rows
        finally:
            conn.close()

    def test_entity_item_roundtrip_and_stale_revision(self):
        saved=self.seed()
        self.assertEqual(self.store.state()['state'],saved['state'])
        payload=self.query("SELECT payload FROM nst_players WHERE entity_id='a'")[0]['payload']
        self.assertNotIn('items',json.loads(payload))
        self.assertEqual(self.query('SELECT COUNT(*) AS n FROM nst_player_items')[0]['n'],2)
        with self.assertRaises(Conflict):
            self.store.commit(0,saved['state'],{})
        saved['state']['players']['a']['items']['stolen']=2
        result=self.store.commit(saved['revision'],saved['state'],{})
        reopened=MariaDBStore(self.config,clock=lambda:self.now)
        self.assertEqual(reopened.state()['state']['players']['a']['items']['stolen'],2)
        self.assertEqual(result['revision'],2)

    def test_two_connections_compete_for_one_item(self):
        initial=self.seed()
        initial['state']['drops']['one']={'items':{'stolen':1}}
        initial=self.store.commit(initial['revision'],initial['state'],{})
        def claim(player):
            other=MariaDBStore(self.config,clock=lambda:self.now)
            candidate=copy.deepcopy(initial['state'])
            del candidate['drops']['one']
            candidate['players'][player]['items']['stolen']=candidate['players'][player]['items'].get('stolen',0)+1
            try:
                other.commit(initial['revision'],candidate,{'action':'loot'})
                return True
            except Conflict:
                return False
            finally:
                other.close()
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            self.assertEqual(sum(pool.map(claim,['a','b'])),1)
        self.assertNotIn('one',self.store.state()['state']['drops'])

    def test_wipe_preservation_backup_idempotence(self):
        self.seed()
        self.query("INSERT INTO nst_accounts VALUES('admin',1,'{}')")
        self.query("INSERT INTO nst_bans VALUES('banned','test',NULL)")
        self.query("INSERT INTO nst_settings VALUES('setting','true')")
        self.assertEqual(self.store.wipe('weekly-test',True)['revision'],1)
        result=self.store.wipe('weekly-test')
        self.assertEqual(result['state']['season'],2)
        self.assertEqual(result['state']['players'],{})
        self.assertEqual(self.store.wipe('weekly-test')['revision'],result['revision'])
        self.assertTrue(self.store.wipe('weekly-test')['alreadyDone'])
        for table in ('accounts','bans','settings','backups','season_history','wipes'):
            self.assertEqual(self.query('SELECT COUNT(*) AS n FROM nst_'+table)[0]['n'],1)

    def test_failure_before_and_after_commit(self):
        self.seed()
        for stage in ('after_backup','before_commit','after_commit'):
            before=self.store.state()
            def failpoint(point):
                if point==stage:
                    raise RuntimeError('simulated disconnect')
            self.store.failpoint=failpoint
            with self.assertRaises(RuntimeError):
                self.store.wipe(stage)
            self.store=MariaDBStore(self.config,clock=lambda:self.now)
            self.store.wipe(stage)
            self.assertEqual(self.store.state()['state']['season'],before['state']['season']+1)
            self.assertTrue(self.store.wipe(stage)['alreadyDone'])

    def test_due_wipe_invalidates_commit(self):
        initial=self.seed()
        self.now=initial['nextWipe']+1
        with self.assertRaises(Conflict):
            self.store.commit(initial['revision'],initial['state'],{})
        self.assertEqual(self.store.state()['state']['season'],2)

    def test_export_restore_and_corruption_rejection(self):
        original=self.seed()
        self.store.wipe('first')
        # A second backup must preserve the first wipe ledger and its FK backup.
        snapshot=self.store.state()
        snapshot['state']['players']['restored']={'cash':123,'items':{'bat':1}}
        snapshot=self.store.commit(snapshot['revision'],snapshot['state'],{})
        result=self.store.wipe('second')
        filename=Path(os.environ['NST_TEST_OUTPUT'])/(uuid.uuid4().hex+'.backup.json')
        self.store.export_backup(result['backup'],filename)
        with self.assertRaises(FileExistsError):
            self.store.export_backup(result['backup'],filename)
        with self.assertRaises(ValueError):
            self.store.restore_file(filename)
        restored_name='nst_test_'+uuid.uuid4().hex
        with self.admin.cursor() as c:
            c.execute('CREATE DATABASE '+restored_name+' CHARACTER SET utf8mb4 COLLATE utf8mb4_bin')
        target=MariaDBStore(dict(self.config,database=restored_name),initialize=True,clock=lambda:self.now+604800)
        target.restore_file(filename,reschedule=True)
        self.assertEqual(target.state()['state'],snapshot['state'])
        self.assertTrue(target.wipe('first')['alreadyDone'])
        archive=json.loads(filename.read_text())
        archive['backups'][0]['payload']='{}'
        bad=filename.with_suffix('.corrupt.json')
        bad.write_text(json.dumps(archive))
        with self.assertRaises(ValueError):
            target.restore_file(bad)

    def test_rollback_gameplay_and_invalid_season(self):
        initial=self.seed()
        candidate=copy.deepcopy(initial['state'])
        candidate['season']=99
        with self.assertRaises(ValueError):
            self.store.commit(initial['revision'],candidate,{})
        candidate=copy.deepcopy(initial['state'])
        candidate['players']['a']['cash']=999
        def failpoint(stage):
            if stage=='before_commit':
                raise RuntimeError('crash')
        # Use direct transaction injection only after the schedule read.
        original_write=self.store._write
        def failed_write(*args):
            original_write(*args)
            raise RuntimeError('crash after row updates')
        self.store._write=failed_write
        with self.assertRaises(RuntimeError):
            self.store.commit(initial['revision'],candidate,{})
        self.store._write=original_write
        self.assertEqual(self.store.state()['state'],initial['state'])

    def test_only_changed_inventory_rows_are_written(self):
        initial=self.seed()
        self.query('CREATE TABLE nst_test_update_counter (n INT NOT NULL) ENGINE=InnoDB')
        self.query('INSERT INTO nst_test_update_counter VALUES(0)')
        self.query('CREATE TRIGGER nst_test_player_updated BEFORE UPDATE ON nst_players FOR EACH ROW UPDATE nst_test_update_counter SET n=n+1')
        initial['state']['players']['a']['items']['stolen']=4
        result=self.store.commit(initial['revision'],initial['state'],{})
        self.assertEqual(result['state']['players']['a']['items']['stolen'],4)
        self.assertEqual(self.query('SELECT n FROM nst_test_update_counter')[0]['n'],0)
        result['state']['players']['a']['cash']=490
        self.store.commit(result['revision'],result['state'],{})
        self.assertEqual(self.query('SELECT n FROM nst_test_update_counter')[0]['n'],1)

    def test_real_lua_reward_roundtrip(self):
        from test_end_to_end import to_lua, to_python
        from lupa.lua54 import LuaRuntime
        lua=LuaRuntime(unpack_returned_tuples=True)
        for filename in ('server/core.lua','shared/config.lua','server/gameplay.lua'):
            lua.execute((Path('resource')/filename).read_text(encoding='utf-8'))
        initial=self.store.state()
        state=to_lua(lua,initial['state'])
        ctx=to_lua(lua,{'id':'license:test','now':1000,'pos':{'x':24.5,'y':-1345.5,'z':29.5},'online':{},'policeCount':0})
        lua.globals().NST.player(state,ctx.id)
        state,_=lua.globals().NST.apply(state,ctx,'robberyStart',to_lua(lua,{'id':'shop'}))
        ctx.online[ctx.id]=to_lua(lua,{'pos':to_python(ctx.pos),'alive':True})
        for second in range(1001,1046):
            ctx.now=second;lua.globals().NST.gameTick(state,ctx)
        state,_=lua.globals().NST.apply(state,ctx,'robberyFinish',to_lua(lua,{'id':'shop'}))
        saved=self.store.commit(initial['revision'],to_python(state),{'action':'robberyFinish'})
        self.assertEqual(saved['state']['players']['license:test']['items']['stolen'],6)
        restored=to_lua(lua,self.store.state()['state'])
        with self.assertRaises(Exception):
            lua.globals().NST.apply(restored,ctx,'robberyFinish',to_lua(lua,{'id':'shop'}))

    def test_service_cli_http_and_conflict_status(self):
        with socket.socket() as probe:
            probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
        env=dict(os.environ,NST_BACKEND='mariadb',NST_DB_HOST='127.0.0.1',
                 NST_DB_PORT=str(self.config['port']),NST_DB_USER='root',NST_DB_NAME=self.name,
                 NST_DB_PASSWORD=self.config['password'],NST_TOKEN='test-only-token-'+'x'*32,
                 PYTHONPATH=str(Path('.testdeps').resolve()))
        env.pop('NST_DB_SSL_CA',None)
        base='http://127.0.0.1:'+str(port)
        headers={'Authorization':'Bearer '+env['NST_TOKEN'],'Content-Type':'application/json'}
        log_path=Path(os.environ['NST_TEST_OUTPUT'])/(uuid.uuid4().hex+'.service.log')
        with log_path.open('w') as log:
            process=subprocess.Popen([sys.executable,'-m','service.server','--backend','mariadb','--port',str(port)],
                                     env=env,stdout=log,stderr=subprocess.STDOUT,
                                     creationflags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0)
            try:
                deadline=time.monotonic()+10
                while True:
                    try:
                        with urlopen(Request(base+'/state',headers=headers),timeout=1) as response:
                            initial=json.load(response)
                        break
                    except URLError:
                        if process.poll() is not None or time.monotonic()>deadline:
                            self.fail('Storage CLI failed to start; see '+str(log_path))
                        time.sleep(0.1)
                with self.assertRaises(HTTPError) as denied:
                    urlopen(base+'/state',timeout=2)
                self.assertEqual(denied.exception.code,401)
                payload=json.dumps({'revision':initial['revision'],'state':initial['state'],'audit':{}}).encode()
                with urlopen(Request(base+'/commit',data=payload,headers=headers),timeout=3) as response:
                    self.assertEqual(json.load(response)['revision'],initial['revision']+1)
                with self.assertRaises(HTTPError) as conflict:
                    urlopen(Request(base+'/commit',data=payload,headers=headers),timeout=3)
                self.assertEqual(conflict.exception.code,409)
            finally:
                process.terminate(); process.wait(timeout=10)
