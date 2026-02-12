import numpy as np
from app.database import predictions_collection

SEQUENCE_LENGTH = 10
MIN_SEQUENCE_LENGTH = 5

def build_temporal_dataset():
    cursor = predictions_collection.find().sort("timestamp", 1)

    sequences = []
    labels = []

    samples = []

    for doc in cursor:
        features = doc.get("features") or {}
        if not isinstance(features, dict):
            continue

        brightness = features.get("brightness")
        edge_density = features.get("edge_density")
        entropy = features.get("entropy")
        if brightness is None or edge_density is None or entropy is None:
            continue

        vector = [
            doc.get("ai_probability", 0.0),
            doc.get("risk_score", 0.0),
            brightness,
            edge_density,
            entropy
        ]
        label = 1 if doc.get("risk_level") in ["WARNING", "IMMINENT"] else 0
        samples.append((vector, label))

    if len(samples) >= SEQUENCE_LENGTH:
        for i in range(len(samples) - SEQUENCE_LENGTH + 1):
            window = [samples[j][0] for j in range(i, i + SEQUENCE_LENGTH)]
            window_label = samples[i + SEQUENCE_LENGTH - 1][1]
            sequences.append(window)
            labels.append(window_label)
    elif len(samples) >= MIN_SEQUENCE_LENGTH:
        # Fallback: train on one shorter sequence when data is limited.
        sequences.append([s[0] for s in samples])
        labels.append(samples[-1][1])

    return np.array(sequences), np.array(labels)
