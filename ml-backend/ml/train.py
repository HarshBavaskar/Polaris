import os
import cv2
import numpy as np
from autoencoder import build_model

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_DIR = os.path.join(BASE_DIR, "..", "data", "normal_sky")

def load_images(path):
    images = []
    for f in os.listdir(path):
        img_path = os.path.join(path, f)
        img = cv2.imread(img_path)
        if img is None:
            continue
        img = cv2.resize(img, (128, 128)) / 255.0
        images.append(img)
    return np.array(images)

X = load_images(DATA_DIR)

print("Training samples:", len(X))

model = build_model()
model.fit(X, X, epochs=20, batch_size=4)

model.save(os.path.join(BASE_DIR, "cloudburst_model.h5"))
print("Model saved successfully")
