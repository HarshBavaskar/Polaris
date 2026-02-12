import os
import shutil
from app.database import predictions_collection, images_collection

DATASET_DIR = "polaris_dataset"
os.makedirs(DATASET_DIR + "/0", exist_ok=True)
os.makedirs(DATASET_DIR + "/1", exist_ok=True)


def build_dataset(limit=500):
    cursor = predictions_collection.find().limit(limit)
    copied = 0

    for pred in cursor:
        image_id = pred["image_id"]
        image_doc = images_collection.find_one({"_id": image_id})
        if not image_doc:
            continue

        feedback_label = (pred.get("authority_feedback") or "").upper()
        if feedback_label in {"TRUE_POSITIVE", "LATE"}:
            label = 1
        elif feedback_label == "FALSE_POSITIVE":
            label = 0
        else:
            label = 1 if pred["risk_level"] in ["WARNING", "IMMINENT"] else 0
        src = image_doc["filepath"]
        dst = f"{DATASET_DIR}/{label}/{os.path.basename(src)}"

        if os.path.exists(src) and not os.path.exists(dst):
            shutil.copy2(src, dst)
            copied += 1

    return copied
