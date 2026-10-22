import shutil

def check_disk_usage():
    """Monitoring script for Edge node."""
    # Path is '/' for Linux (Edge)
    path = "/"
    try:
        total, used, free = shutil.disk_usage(path)
        percent_used = (used / total) * 100
        print(f"Disk Usage for {path}: {percent_used:.2f}%")
        if percent_used > 80:
            print("WARNING: Disk usage is above 80%!")
        else:
            print("Disk usage is within safe limits.")
    except Exception as e:
        print(f"Error checking disk usage: {e}")

if __name__ == "__main__":
    check_disk_usage()
