import torch
import torch.nn as nn
import numpy as np
import threading

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MODEL_PATH = "polaris_lstm.pth"

class TemporalLSTM(nn.Module):
    def __init__(self):
        super().__init__()
        self.lstm = nn.LSTM(input_size=5, hidden_size=32, batch_first=True)
        self.fc = nn.Linear(32, 2)

    def forward(self, x):
        _, (h_n, _) = self.lstm(x)
        return self.fc(h_n[-1])


_model_lock = threading.Lock()
_model = None


def reload_temporal_model():
    global _model
    with _model_lock:
        model = TemporalLSTM().to(DEVICE)
        model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
        model.eval()
        _model = model


def _ensure_model_loaded():
    global _model
    if _model is None:
        reload_temporal_model()

def temporal_predict(sequence):
    _ensure_model_loaded()
    seq = torch.tensor(sequence, dtype=torch.float32).unsqueeze(0).to(DEVICE)

    with _model_lock:
        with torch.no_grad():
            out = _model(seq)
            probs = torch.softmax(out, dim=1)

    return float(probs[0][1])
