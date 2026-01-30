import cv2
import numpy as np

def preprocess(frame):
    frame = cv2.resize(frame, (128, 128))
    frame = frame / 255.0
    return np.expand_dims(frame, axis=0)
