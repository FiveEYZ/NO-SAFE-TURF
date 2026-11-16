"""Run from repository root. Never connects to FiveM or production data."""
import pathlib
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / '.testdeps'))
from lupa.lua54 import LuaRuntime

def main():
    import os
    os.chdir(ROOT)
    suites = unittest.defaultTestLoader.discover('tests', pattern='test_*.py')
    result = unittest.TextTestRunner(verbosity=2).run(suites)
    if not result.wasSuccessful():
        return 1
    for path in sorted((ROOT / 'resource').rglob('*.lua')):
        LuaRuntime().execute('assert(load(...))', path.read_text(encoding='utf-8-sig'))
    for path in sorted((ROOT / 'tests').glob('*_spec.lua')):
        LuaRuntime().execute(path.read_text(encoding='utf-8-sig'))
    for path in (ROOT / 'resource/web').glob('*.js'):
        subprocess.run(['node', '--check', str(path)], check=True)
    subprocess.run(['node', 'tests/web_spec.js'], check=True)
    print('PASS: Python suites, Lua 5.4 compilation + specs, JavaScript syntax and NUI DOM contracts.')
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
