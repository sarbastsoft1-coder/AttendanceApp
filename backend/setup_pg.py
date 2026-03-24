import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
import os

passwords = ["postgres", "root", "admin", "password", "123456", ""]
success = False
correct_pw = ""

print("Attempting to connect to PostgreSQL on localhost:5432...")
for pw in passwords:
    try:
        # Connect to default 'postgres' database to create the new one
        conn = psycopg2.connect(
            user="postgres",
            password=pw,
            host="localhost",
            port="5432",
            database="postgres"
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        print(f"Successfully connected with password: '{pw}'")
        
        # Check if database exists
        cursor.execute("SELECT 1 FROM pg_catalog.pg_database WHERE datname = 'attendance_db'")
        exists = cursor.fetchone()
        
        if not exists:
            cursor.execute("CREATE DATABASE attendance_db")
            print("Created database 'attendance_db'!")
        else:
            print("Database 'attendance_db' already exists.")
            
        cursor.close()
        conn.close()
        success = True
        correct_pw = pw
        break
    except Exception as e:
        # print(f"Failed with password '{pw}': {e}")
        pass

if success:
    env_path = ".env"
    db_url = f"DATABASE_URL=postgresql://postgres:{correct_pw}@localhost:5432/attendance_db\n"
    
    # Read existing or create new
    if os.path.exists(env_path):
        with open(env_path, "r") as f:
            lines = f.readlines()
            
        # Remove old DATABASE_URL
        lines = [l for l in lines if not l.startswith("DATABASE_URL=")]
        lines.append(db_url)
        
        with open(env_path, "w") as f:
            f.writelines(lines)
    else:
        with open(env_path, "w") as f:
            f.write(db_url)
            
    print("SUCCESS: Updated .env file in backend directory!")
else:
    print("FAILED: Could not connect to PostgreSQL with common default passwords.")
