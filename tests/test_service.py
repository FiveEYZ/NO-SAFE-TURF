import concurrent.futures
import copy
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import threading
import unittest
from urllib.request import Request, urlopen
from urllib.error import HTTPError
from http.server import ThreadingHTTPServer

from service.server import Store, Schedule, Conflict, restore, handler_for


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.path=Path(self.temp.name)/'world.sqlite3'
        self.now=1794672000
        self.store=Store(self.path,clock=lambda:self.now)

    def tearDown(self):
        self.store.close()
        self.temp.cleanup()

    def test_two_claims_one_commit(self):
        initial=self.store.state()
        initial['state']['drops']={'one':{'items':{'stolen':1}}}
        self.store.commit(0,initial['state'],{'action':'seed'})
        state=self.store.state()
        def claim(actor):
            claimed=copy.deepcopy(state['state'])
            claimed['drops'].pop('one')
            claimed['players'][actor]={'items':{'stolen':1}}
            try:
                self.store.commit(state['revision'],claimed,{'action':'loot','actor':actor})
                return True
            except Conflict:
                return False
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results=list(pool.map(claim,['a','b']))
        self.assertEqual(sum(results),1)
        self.assertEqual(len(self.store.state()['state']['players']),1)

    def test_replayed_reward_rejected(self):
        initial=self.store.state()
        initial['state']['players']['a']={'cash':100}
        self.store.commit(initial['revision'],initial['state'],{'action':'reward'})
        with self.assertRaises(Conflict):
            self.store.commit(initial['revision'],initial['state'],{'action':'reward'})

    def test_wipe_preserves_accounts_and_history_and_is_idempotent(self):
        self.store.db.execute("INSERT INTO accounts VALUES('account',1,'{}')")
        self.store.db.execute("INSERT INTO bans VALUES('banned','test',NULL)")
        current=self.store.state()
        current['state']['gangs']['g']={'name':'Gang','score':42}
        self.store.commit(0,current['state'],{})
        self.assertEqual(self.store.wipe('test',True)['revision'],1)
        wiped=self.store.wipe('test')
        self.assertEqual(wiped['state']['season'],2)
        again=self.store.wipe('test')
        self.assertTrue(again['alreadyDone'])
        self.assertEqual(again['revision'],wiped['revision'])
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM accounts').fetchone()[0],1)
        self.assertEqual(self.store.db.execute('SELECT COUNT(*) FROM bans').fetchone()[0],1)
        rankings=json.loads(self.store.db.execute('SELECT leaderboard FROM season_history').fetchone()[0])
        self.assertEqual(rankings[0]['score'],42)

    def test_crash_restart_before_and_after_commit(self):
        for stage in ['after_backup','before_commit','after_commit']:
            key='crash:'+stage
            before=self.store.state()['state']['season']
            def failpoint(point):
                if point==stage:
                    raise RuntimeError('simulated process failure')
            self.store.failpoint=failpoint
            with self.assertRaises(RuntimeError):
                self.store.wipe(key)
            self.store.close()
            self.store=Store(self.path,clock=lambda:self.now)
            self.store.wipe(key)
            self.assertEqual(self.store.state()['state']['season'],before+1)
            self.assertTrue(self.store.wipe(key)['alreadyDone'])

    def test_restore_backup(self):
        initial=self.store.state()
        initial['state']['players']['x']={'cash':123}
        self.store.commit(0,initial['state'],{})
        result=self.store.wipe('restore')
        recovered_path=Path(self.temp.name)/'recovered.sqlite3'
        restore(result['backup'],recovered_path)
        recovered=Store(recovered_path,clock=lambda:self.now)
        try:
            self.assertEqual(recovered.state()['state']['players']['x']['cash'],123)
            self.assertEqual(recovered.state()['state']['season'],1)
        finally:
            recovered.close()
        with self.assertRaises(ValueError):
            restore(result['backup'],recovered_path)

    def test_retry_manual_wipe_backups_latest_revision(self):
        def failpoint(stage):
            if stage=='after_backup':
                raise RuntimeError('interrupted manual wipe')
        self.store.failpoint=failpoint
        with self.assertRaises(RuntimeError):
            self.store.wipe('retry-manual')
        self.store.failpoint=None
        current=self.store.state()
        current['state']['players']['new']={'cash':456}
        self.store.commit(current['revision'],current['state'],{})
        result=self.store.wipe('retry-manual')
        recovered_path=Path(self.temp.name)/'latest.sqlite3'
        restore(result['backup'],recovered_path)
        recovered=Store(recovered_path,clock=lambda:self.now)
        try:
            self.assertEqual(recovered.state()['state']['players']['new']['cash'],456)
            self.assertEqual(len(list(self.store.backups.glob('*.sqlite3'))),2)
        finally:
            recovered.close()

    def test_due_wipe_invalidates_stale_commit(self):
        old=self.store.state()
        self.now=old['nextWipe']+1
        with self.assertRaises(Conflict):
            self.store.commit(old['revision'],old['state'],{})
        self.assertEqual(self.store.state()['state']['season'],2)

    def test_restore_expired_season_with_explicit_reschedule(self):
        old=self.store.state()
        old['state']['players']['restored']={'cash':321}
        self.store.commit(old['revision'],old['state'],{})
        self.now=old['nextWipe']+60
        wiped=self.store.wipe('restore-expired')
        destination=Path(self.temp.name)/'rescheduled.sqlite3'
        restore(wiped['backup'],destination,reschedule=Schedule(),now=self.now)
        recovered=Store(destination,clock=lambda:self.now)
        try:
            result=recovered.state()
            self.assertEqual(result['state']['season'],1)
            self.assertEqual(result['state']['players']['restored']['cash'],321)
            self.assertGreater(result['nextWipe'],self.now)
            self.assertEqual(recovered.db.execute("SELECT COUNT(*) FROM audit WHERE action='restore_reschedule'").fetchone()[0],1)
        finally:
            recovered.close()

    def test_season_change_blocked(self):
        state=self.store.state()['state']
        state['season']=99
        with self.assertRaises(ValueError):
            self.store.commit(0,state,{})

    def test_http_auth_and_commit(self):
        token='x'*32
        server=ThreadingHTTPServer(('127.0.0.1',0),handler_for(self.store,token))
        thread=threading.Thread(target=server.serve_forever,daemon=True)
        thread.start()
        base='http://127.0.0.1:'+str(server.server_port)
        try:
            with self.assertRaises(HTTPError) as caught:
                urlopen(base+'/state')
            self.assertEqual(caught.exception.code,401)
            request=Request(base+'/state',headers={'Authorization':'Bearer '+token})
            with urlopen(request) as response:
                state=json.load(response)
            body=json.dumps({'revision':state['revision'],'state':state['state'],'audit':{}}).encode()
            with urlopen(Request(base+'/commit',data=body,headers={'Authorization':'Bearer '+token})) as response:
                self.assertEqual(json.load(response)['revision'],1)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()


class ScheduleTests(unittest.TestCase):
    def test_dst_spring_gap_moves_forward(self):
        schedule=Schedule(6,2,30)
        before=datetime(2026,3,28,12,tzinfo=timezone.utc).timestamp()
        when=datetime.fromtimestamp(schedule.next_after(before),schedule.zone)
        self.assertEqual((when.day,when.hour,when.minute),(29,3,30))

    def test_dst_autumn_uses_first_occurrence_once(self):
        schedule=Schedule(6,2,30)
        before=datetime(2026,10,24,12,tzinfo=timezone.utc).timestamp()
        epoch=schedule.next_after(before)
        when=datetime.fromtimestamp(epoch,schedule.zone)
        self.assertEqual(when.fold,0)
        self.assertEqual(datetime.fromtimestamp(schedule.next_after(epoch),schedule.zone).day,1)

    def test_stockholm_default_tracks_dst(self):
        schedule=Schedule()
        winter=schedule.next_after(datetime(2026,1,1,tzinfo=timezone.utc).timestamp())
        summer=schedule.next_after(datetime(2026,7,1,tzinfo=timezone.utc).timestamp())
        self.assertEqual(datetime.fromtimestamp(winter,timezone.utc).hour,3)
        self.assertEqual(datetime.fromtimestamp(summer,timezone.utc).hour,2)


if __name__=='__main__':
    unittest.main()
