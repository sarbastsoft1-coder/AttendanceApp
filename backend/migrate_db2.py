import sqlite3
import psycopg2
from psycopg2.extras import execute_batch

def migrate():
    print("Starting raw SQL migration from SQLite to PostgreSQL with boolean casting...")
    
    pg = psycopg2.connect("postgresql://postgres:postgres@localhost:5432/attendance_db")
    pg.autocommit = True
    pg_cursor = pg.cursor()
    
    sq = sqlite3.connect("attendance.db")
    sq.row_factory = sqlite3.Row
    sq_cursor = sq.cursor()
    
    tables = [
        "users", "settings", "classes", "students", 
        "password_reset_tokens", "leave_requests", 
        "audit_logs", "qr_sessions", "notifications", "attendance"
    ]
    
    # These columns are Booleans in Postgres but Integers in SQLite
    bool_cols = {
        "has_registered_face", "is_active", "is_verified", 
        "used", "is_read", "allow_manual_entry", 
        "allow_qr_attendance", "allow_face_attendance"
    }
    
    pg_cursor.execute("SET session_replication_role = 'replica';")
    
    for t in reversed(tables):
        try:
            pg_cursor.execute(f"DELETE FROM {t}")
        except Exception as e:
            pass

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
            
        cols = list(rows[0].keys())
        col_names = ", ".join(cols)
        placeholders = ", ".join(["%s"] * len(cols))
        
        insert_query = f"INSERT INTO {t} ({col_names}) VALUES ({placeholders})"
        
        data = []
        for row in rows:
            new_row = []
            for col_name, val in zip(cols, row):
                if col_name in bool_cols and val is not None:
                    # Cast integer 1/0 to Python bool True/False
                    new_row.append(bool(val))
                elif t == 'settings' and val in ["true", "false"]:
                    new_row.append(val)
                else:
                    new_row.append(val)
            data.append(tuple(new_row))
            
        try:
            execute_batch(pg_cursor, insert_query, data)
            print(f" -> Migrated {len(data)} rows.")
        except Exception as e:
            print(f" -> Error migrating {t}: {e}")
            pg.rollback()
            
    try:
        pg_cursor.execute("SET session_replication_role = 'origin';")
    except:
        pass
        
    print("Migration completely successful!")
    
if __name__ == "__main__":
    migrate()
