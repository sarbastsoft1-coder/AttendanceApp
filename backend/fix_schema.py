import psycopg2

conn = psycopg2.connect("postgresql://postgres:postgres@localhost:5432/attendance_db")
conn.autocommit = True
cur = conn.cursor()

# Check existing columns
cur.execute("SELECT column_name FROM information_schema.columns WHERE table_name = 'users' ORDER BY ordinal_position")
cols = [r[0] for r in cur.fetchall()]
print("Existing columns:", cols)

# Add any missing columns
missing = []

if "verification_token" not in cols:
    cur.execute("ALTER TABLE users ADD COLUMN verification_token VARCHAR(64)")
    missing.append("verification_token")

if missing:
    print("Added missing columns:", missing)
else:
    print("All columns exist. Checking for other issues...")

# Try a quick test insert and rollback
conn.autocommit = False
try:
    import secrets
    cur.execute("""INSERT INTO users (email, full_name, hashed_password, role, verification_token, is_active, is_verified, has_registered_face)
                   VALUES ('__test__@test.com', 'Test', 'hash', 'student', %s, true, false, false)""",
                (secrets.token_hex(16),))
    conn.rollback()
    print("Test insert succeeded - registration should work!")
except Exception as e:
    conn.rollback()
    print("Insert error:", e)
