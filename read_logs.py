import os

files = [
    r"c:\Users\sarba\OneDrive\Desktop\project kolez\recognition_based_automated_attendance_system\flutter_doctor_full.txt",
    r"c:\Users\sarba\OneDrive\Desktop\project kolez\recognition_based_automated_attendance_system\build_verbose_new.txt"
]

for f in files:
    if os.path.exists(f):
        print(f"--- CONTENT OF {f} ---")
        try:
            # Try utf-16le first
            with open(f, 'r', encoding='utf-16le') as fh:
                print(fh.read())
        except Exception:
            try:
                # Fallback to utf-8
                with open(f, 'r', encoding='utf-8') as fh:
                    print(fh.read())
            except Exception as e:
                print(f"Error reading {f}: {e}")
        print("-" * 50)
