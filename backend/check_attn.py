import psycopg2

conn = psycopg2.connect("postgresql://postgres:postgres@localhost:5432/attendance_db")
cur = conn.cursor()

cur.execute("SELECT DISTINCT user_id FROM attendance ORDER BY user_id")
att_user_ids = [r[0] for r in cur.fetchall()]
print("User IDs with attendance records:", att_user_ids)

cur.execute("SELECT id, email, role FROM users ORDER BY id")
users = cur.fetchall()
print("All users in DB:")
for u in users:
    print(f"  id={u[0]}  email={u[1]}  role={u[2]}")
