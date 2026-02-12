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

def train_lstm(
    model_path: str = "polaris_lstm.pth",
    epochs: int = 10,
    learning_rate: float = 1e-3,
):
    X, y = build_temporal_dataset()
    if len(X) == 0:
        return {
            "skipped": True,
            "reason": "Temporal dataset is empty.",
            "samples": 0,
            "epochs": 0,
            "model_path": model_path,
        }

    X_tensor = torch.tensor(X, dtype=torch.float32).to(DEVICE)
    y_tensor = torch.tensor(y, dtype=torch.long).to(DEVICE)

    model = TemporalLSTM().to(DEVICE)
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    last_loss = None

    for epoch in range(epochs):
        optimizer.zero_grad()
        outputs = model(X_tensor)
        loss = criterion(outputs, y_tensor)
        loss.backward()
        optimizer.step()
        last_loss = float(loss.item())

        print(f"Epoch {epoch + 1}, Loss: {last_loss:.4f}")

    torch.save(model.state_dict(), model_path)
    print("Temporal model saved")

    return {
        "skipped": False,
        "samples": len(X),
        "epochs": epochs,
        "last_epoch_loss": round(last_loss or 0.0, 4),
        "model_path": model_path,
    }


if __name__ == "__main__":
    train_lstm()
