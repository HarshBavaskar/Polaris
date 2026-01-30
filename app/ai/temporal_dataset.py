import numpy as np
from app.database import predictions_collection

SEQUENCE_LENGTH = 10

def build_temporal_dataset():
    cursor = predictions_collection.find().sort("timestamp", 1)

    sequences = []
    labels = []

    buffer = []

    for doc in cursor:
        vector = [
            doc.get("ai_probability", 0.0),
            doc.get("risk_score", 0.0),
            doc["features"]["brightness"],
            doc["features"]["edge_density"],
            doc["features"]["entropy"]
        ]

        buffer.append(vector)

        if len(buffer) == SEQUENCE_LENGTH:
            sequences.append(buffer.copy())

            label = 1 if doc["risk_level"] in ["WARNING", "IMMINENT"] else 0
            labels.append(label)

            buffer.pop(0)

    return np.array(sequences), np.array(labels)
