import requests

# Login as ss@gmail.com (id=2, has attendance records)
login = requests.post("http://localhost:8000/api/auth/login-json", json={
    "email": "ss@gmail.com",
    "password": "123456"
})
print("Login status:", login.status_code)

if login.status_code != 200:
    print("Login failed:", login.text)
    exit()

token = login.json()["token"]["access_token"]
headers = {"Authorization": f"Bearer {token}"}

# Test history endpoint
r = requests.get("http://localhost:8000/api/attendance/history", headers=headers)
print("History status:", r.status_code)
print("History response:", r.text[:500])
