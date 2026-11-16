"""Real Lua transitions round-trip through real SQLite JSON storage."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / '.testdeps'))
from lupa.lua54 import LuaRuntime
from service.server import Store, Conflict

def to_lua(lua, obj):
    if isinstance(obj, dict):
        return lua.table_from({key: to_lua(lua, value) for key, value in obj.items()})
    if isinstance(obj, list):
        return lua.table_from([to_lua(lua, value) for value in obj])
    return obj

def to_python(obj):
    if hasattr(obj, 'items'):
        return {key: to_python(value) for key, value in obj.items()}
    return obj

class EndToEndTests(unittest.TestCase):
    def test_lua_reward_sqlite_commit_replay_restart(self):
        lua = LuaRuntime(unpack_returned_tuples=True)
        for filename in ('server/core.lua', 'shared/config.lua', 'server/gameplay.lua', 'server/police.lua'):
            lua.execute((Path('resource') / filename).read_text(encoding='utf-8'))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'world.sqlite3'
            store = Store(path)
            envelope = store.state()
            state = to_lua(lua, envelope['state'])
            ctx = to_lua(lua, {'id':'license:test', 'now':1000, 'pos':{'x':24.5,'y':-1345.5,'z':29.5}, 'online':{}, 'policeCount':0})
            lua.globals().NST.player(state, ctx.id)
            state, _ = lua.globals().NST.apply(state, ctx, 'robberyStart', to_lua(lua, {'id':'shop'}))
            ctx.online[ctx.id] = to_lua(lua, {'pos':to_python(ctx.pos),'alive':True})
            for second in range(1001, 1046):
                ctx.now = second
                lua.globals().NST.gameTick(state, ctx)
            state, _ = lua.globals().NST.apply(state, ctx, 'robberyFinish', to_lua(lua, {'id':'shop'}))
            committed = store.commit(envelope['revision'], to_python(state), {'action':'reward','actor':'test'})
            with self.assertRaises(Conflict):
                store.commit(envelope['revision'], to_python(state), {'action':'duplicate'})
            restored = to_lua(lua, json.loads(json.dumps(committed['state'])))
            with self.assertRaises(Exception):
                lua.globals().NST.apply(restored, ctx, 'robberyFinish', to_lua(lua, {'id':'shop'}))
            store.close()
            store = Store(path)
            self.assertEqual(store.state()['state']['players']['license:test']['items']['stolen'], 6)
            store.close()
