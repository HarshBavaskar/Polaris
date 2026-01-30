from app.utils.image_processing import extract_features
from app.utils.risk_logic import calculate_risk, risk_level
import os

image_path = "app/uploads"

for img in os.listdir(image_path):
    if img.endswith(".jpg"):
        features = extract_features(f"{image_path}/{img}")
        risk = calculate_risk(features)
        level = risk_level(risk)

        print(img)
        print(" Features:", features)
        print(" Risk:", risk, level)
        print("-" * 40)
