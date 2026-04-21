import psycopg2
import sys

def check_db(db_name):
    try:
        conn = psycopg2.connect(f'postgresql://postgres:postgres@localhost:5432/{db_name}')
        cursor = conn.cursor()
        cursor.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public'")
        tables = cursor.fetchall()
        print(f"Tables in {db_name}: {[t[0] for t in tables]}")
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"Error connecting to {db_name}: {e}")

if __name__ == "__main__":
    check_db('identity_db')
