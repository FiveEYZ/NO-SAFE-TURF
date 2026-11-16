"""Optional development-only, read-only connection check. Never initializes schema."""
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.testdeps'))
import pymysql

def main():
    config=json.loads((ROOT/'deploy/mariadb.private.json').read_text(encoding='utf-8'))
    config.update(connect_timeout=5,read_timeout=5,write_timeout=5,charset='utf8mb4',autocommit=False)
    try:
        connection=pymysql.connect(**config)
        try:
            with connection.cursor() as cursor:
                cursor.execute('START TRANSACTION READ ONLY')
                cursor.execute('SELECT VERSION()')
                print('Database version:',cursor.fetchone()[0])
                cursor.execute('SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE()')
                print('Existing table count:',cursor.fetchone()[0])
                cursor.execute("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema=DATABASE() AND table_name='nst_meta'")
                print('NO SAFE TURF metadata present:',bool(cursor.fetchone()[0]))
            connection.rollback()
        finally:
            connection.close()
        print('Read-only connection check passed. No database data changed.')
        return 0
    except Exception as exc:
        code=exc.args[0] if exc.args and isinstance(exc.args[0],int) else type(exc).__name__
        print('Read-only connection check failed. Error code:',code)
        return 1

if __name__=='__main__':
    raise SystemExit(main())
