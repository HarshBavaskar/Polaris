import cv2
import numpy as np
from tensorflow.keras.models import load_model

MODEL_PATH = "cloudburst_model.h5"

model = load_model(MODEL_PATH, compile=False)

def preprocess_image(frame):
    img = cv2.resize(frame, (128, 128))
    img = img / 255.0
    img = np.expand_dims(img, axis=0)
    return img

def anomaly_score(frame):
    img = preprocess_image(frame)
    reconstruction = model.predict(img, verbose=0)
    error = np.mean((img - reconstruction) ** 2)
    return float(error)
