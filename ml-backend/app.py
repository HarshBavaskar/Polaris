from fastapi import FastAPI
from camera.capture import capture_frame
from utils.preprocess import preprocess
from ml.predict import anomaly_score

app = FastAPI()

@app.get("/analyze")
def analyze():
    frame = capture_frame()
    if frame is None:
        return {"error": "Camera error"}

    img = preprocess(frame)
    score = anomaly_score(img)

    status = "ANOMALY" if score > 0.02 else "NORMAL"
    return {
        "anomaly_score": float(score),
        "status": status
    }
