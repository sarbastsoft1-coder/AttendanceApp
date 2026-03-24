import psycopg2

conn = psycopg2.connect("postgresql://postgres:postgres@localhost:5432/attendance_db")
conn.autocommit = True
cur = conn.cursor()

# Tables that have auto-increment IDs
tables = [
    "users", "attendance", "classes", "students",
    "password_reset_tokens", "leave_requests",
    "audit_logs", "qr_sessions", "notifications", "settings"
]

for table in tables:
    try:
        # Get the max ID in the table
        cur.execute(f"SELECT MAX(id) FROM {table}")
        max_id = cur.fetchone()[0]
        if max_id is None:
            max_id = 0
        
        seq_name = f"{table}_id_seq"
        # Set the sequence's next value to max_id + 1
        cur.execute(f"SELECT setval('{seq_name}', %s, true)", (max_id,))
        print(f"Reset sequence '{seq_name}' to {max_id}")
    except Exception as e:
        print(f"Skipped {table}: {e}")

print("All sequences reset successfully!")
