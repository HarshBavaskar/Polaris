from app.utils.image_processing import extract_features


image_path = "app/uploads"  # folder with images

import os

for img in os.listdir(image_path):
    if img.endswith(".jpg"):
        features = extract_features(f"{image_path}/{img}")
        print(img, features)
