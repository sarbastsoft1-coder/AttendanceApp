import psycopg2

conn = psycopg2.connect("postgresql://postgres:postgres@localhost:5432/attendance_db")
conn.autocommit = True
cur = conn.cursor()

cur.execute("UPDATE users SET role='teacher' WHERE role='student'")
print(f"Updated {cur.rowcount} users to teacher role")

cur.execute("SELECT id, email, full_name, role FROM users ORDER BY id")
for row in cur.fetchall():
    print(row)
