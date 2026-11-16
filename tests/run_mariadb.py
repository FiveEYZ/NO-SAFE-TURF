"""Start a disposable Windows MariaDB on loopback; never use production credentials.

Download and verify the portable archive as documented in docs/MARIADB.md first.
Does not install a Windows service or delete pre-existing files/databases.
"""
from pathlib import Path
import os
import secrets
import socket
import subprocess
import sys
import time
import unittest
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
sys.path.insert(0,str(ROOT/'.testdeps'))


def main():
    import pymysql
    os.chdir(ROOT)
    binaries=ROOT/'.testtools/mariadb-11.4.5-winx64/bin'
    if not binaries.is_dir():
        raise SystemExit('Portable test binaries not found; see docs/MARIADB.md')
    output=ROOT/'.testdata'/uuid.uuid4().hex
    output.mkdir(parents=True)
    data=output/'data'
    with socket.socket() as probe:
        probe.bind(('127.0.0.1',0)); port=probe.getsockname()[1]
    password=secrets.token_hex(24)
    flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
    with (output/'initialize.log').open('w') as log:
        subprocess.run([str(binaries/'mariadb-install-db.exe'),'--datadir='+str(data),
                        '--password='+password,'--port='+str(port)],stdout=log,stderr=subprocess.STDOUT,
                       check=True,timeout=60,creationflags=flags)
    log=(output/'server.log').open('w')
    process=subprocess.Popen([str(binaries/'mariadbd.exe'),'--defaults-file='+str(data/'my.ini'),
                              '--bind-address=127.0.0.1','--port='+str(port),'--console'],
                             stdout=log,stderr=subprocess.STDOUT,creationflags=flags)
    connection=None
    try:
        deadline=time.monotonic()+40
        while time.monotonic()<deadline:
            try:
                connection=pymysql.connect(host='127.0.0.1',port=port,user='root',password=password,connect_timeout=1)
                break
            except pymysql.Error:
                if process.poll() is not None:
                    raise RuntimeError('Isolated MariaDB stopped; inspect '+str(output/'server.log'))
                time.sleep(0.2)
        if connection is None:
            raise RuntimeError('Isolated MariaDB startup timeout')
        with connection.cursor() as cursor:
            cursor.execute('SELECT VERSION()'); print('Isolated MariaDB:',cursor.fetchone()[0])
        os.environ.update(NST_ISOLATED_MARIADB_TEST='1',NST_TEST_DB_PORT=str(port),
                          NST_TEST_DB_PASSWORD=password,NST_TEST_OUTPUT=str(output))
        suite=unittest.defaultTestLoader.discover('tests',pattern='test_mariadb.py')
        result=unittest.TextTestRunner(verbosity=2).run(suite)
        return 0 if result.wasSuccessful() else 1
    finally:
        if connection:
            try:
                with connection.cursor() as cursor:
                    cursor.execute('SHUTDOWN')
            except pymysql.Error:
                pass
            connection.close()
        try:
            process.wait(timeout=15)
        except subprocess.TimeoutExpired:
            process.terminate(); process.wait(timeout=10)
        log.close()
        os.environ.pop('NST_TEST_DB_PASSWORD',None)
        print('Isolated server stopped. Test artifacts:',output.relative_to(ROOT))


if __name__=='__main__':
    raise SystemExit(main())
