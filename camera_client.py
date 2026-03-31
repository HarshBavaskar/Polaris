import cv2
import time
import requests
from datetime import datetime
import os

from app.auth.client_auth import build_auth_headers

SERVER_URL = "http://127.0.0.1:8000/input/camera"
TEMP_DIR = "temp_images"
os.makedirs(TEMP_DIR, exist_ok=True)

cap = cv2.VideoCapture(0)

if not cap.isOpened():
    print("ERROR: Cannot access camera")
    exit()

print("Laptop camera started. Press CTRL+C to stop.")

try:
    while True:
        ret, frame = cap.read()
        if not ret:
            print("Failed to capture image")
            break

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        image_path = f"{TEMP_DIR}/{timestamp}.jpg"

        cv2.imwrite(image_path, frame)

        with open(image_path, "rb") as img:
            base_url = SERVER_URL.rsplit("/input/camera", 1)[0]
            response = requests.post(
                SERVER_URL,
                headers=build_auth_headers(base_url, preferred_role="ingest"),
                files={"image": (os.path.basename(image_path), img, "image/jpeg")},
                timeout=20,
            )

        print("Server response:", response.json())

        time.sleep(5)

except KeyboardInterrupt:
    print("\nStopping camera...")

cap.release()
