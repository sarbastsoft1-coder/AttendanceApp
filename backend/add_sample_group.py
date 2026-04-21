import psycopg2

def check_groups():
    try:
        conn = psycopg2.connect('postgresql://postgres:postgres@localhost:5432/attendance_db')
        cursor = conn.cursor()
        
        cursor.execute("SELECT id, name, created_by_id FROM teacher_groups")
        groups = cursor.fetchall()
        print(f"Current groups: {groups}")
        
        if not groups:
            cursor.execute("SELECT id, email FROM users WHERE role IN ('admin', 'super_admin', 'super_teacher') LIMIT 1")
            user = cursor.fetchone()
            if user:
                print(f"Found admin user: {user}")
                cursor.execute(
                    "INSERT INTO teacher_groups (name, description, created_by_id, created_at, updated_at) VALUES (%s, %s, %s, NOW(), NOW()) RETURNING id",
                    ("Test Group 1", "Automatically created test group", user[0])
                )
                group_id = cursor.fetchone()[0]
                cursor.execute(
                    "INSERT INTO teacher_group_members (group_id, teacher_id, joined_at) VALUES (%s, %s, NOW())",
                    (group_id, user[0])
                )
                conn.commit()
                print(f"Successfully added 'Test Group 1' (ID: {group_id}) for user {user[1]}")
            else:
                print("No eligible user found to create a group.")
        
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    check_groups()
