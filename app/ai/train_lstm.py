import torch
import torch.nn as nn
from app.ai.temporal_dataset import build_temporal_dataset

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

X, y = build_temporal_dataset()

X = torch.tensor(X, dtype=torch.float32)
y = torch.tensor(y, dtype=torch.long)

class TemporalLSTM(nn.Module):
    def __init__(self):
        super().__init__()
        self.lstm = nn.LSTM(input_size=5, hidden_size=32, batch_first=True)
        self.fc = nn.Linear(32, 2)

    def forward(self, x):
        _, (h_n, _) = self.lstm(x)
        return self.fc(h_n[-1])

model = TemporalLSTM().to(DEVICE)
criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

X, y = X.to(DEVICE), y.to(DEVICE)

for epoch in range(10):
    optimizer.zero_grad()
    outputs = model(X)
    loss = criterion(outputs, y)
    loss.backward()
    optimizer.step()

    print(f"Epoch {epoch+1}, Loss: {loss.item():.4f}")

torch.save(model.state_dict(), "polaris_lstm.pth")
print("Temporal model saved")
