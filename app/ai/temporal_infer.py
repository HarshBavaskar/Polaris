import torch
import torch.nn as nn
import numpy as np

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

class TemporalLSTM(nn.Module):
    def __init__(self):
        super().__init__()
        self.lstm = nn.LSTM(input_size=5, hidden_size=32, batch_first=True)
        self.fc = nn.Linear(32, 2)

    def forward(self, x):
        _, (h_n, _) = self.lstm(x)
        return self.fc(h_n[-1])

model = TemporalLSTM().to(DEVICE)
model.load_state_dict(torch.load("polaris_lstm.pth", map_location=DEVICE))
model.eval()

def temporal_predict(sequence):
    seq = torch.tensor(sequence, dtype=torch.float32).unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        out = model(seq)
        probs = torch.softmax(out, dim=1)

    return float(probs[0][1])
