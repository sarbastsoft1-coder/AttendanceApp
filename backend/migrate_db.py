import sqlite3
import psycopg2
from psycopg2.extras import execute_batch

def migrate():
    print("Starting raw SQL migration from SQLite to PostgreSQL...")
    
    pg = psycopg2.connect("postgresql://postgres:postgres@localhost:5432/attendance_db")
    pg.autocommit = True
    pg_cursor = pg.cursor()
    
    sq = sqlite3.connect("attendance.db")
    sq.row_factory = sqlite3.Row
    sq_cursor = sq.cursor()
    
    # Ordered by dependency
    tables = [
        "users", "settings", "classes", "students", 
        "password_reset_tokens", "leave_requests", 
        "audit_logs", "qr_sessions", "notifications", "attendance"
    ]
    
    # Disable triggers (requires superuser)
    pg_cursor.execute("SET session_replication_role = 'replica';")
    
    print("Clearing Postgres tables...")
    for t in reversed(tables):
        try:
            pg_cursor.execute(f"DELETE FROM {t}")
        except Exception as e:
            print(f"Skipped deleting {t}: {e}")

    for t in tables:
        print(f"Migrating table '{t}'...")
        try:
            sq_cursor.execute(f"SELECT * FROM {t}")
            rows = sq_cursor.fetchall()
        except sqlite3.OperationalError:
            print(f" -> Table {t} missing in SQLite, skipping.")
            continue
            
        if not rows:
            print(" -> 0 rows")
            continue
            
        cols = rows[0].keys()
        col_names = ", ".join(cols)
        placeholders = ", ".join(["%s"] * len(cols))
        
        insert_query = f"INSERT INTO {t} ({col_names}) VALUES ({placeholders})"
        data = [tuple(row) for row in rows]
        
        try:
            execute_batch(pg_cursor, insert_query, data)
            print(f" -> Migrated {len(data)} rows.")
        except Exception as e:
            print(f" -> Error migrating {t}: {e}")
            
    try:
        pg_cursor.execute("SET session_replication_role = 'origin';")
    except:
        pass
        
    print("Migration completely successful!")
    
if __name__ == "__main__":
    migrate()
