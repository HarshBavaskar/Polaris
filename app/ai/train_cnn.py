import torch
import torch.nn as nn
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

transform = transforms.Compose([transforms.Resize((224, 224)), transforms.ToTensor()])

def train_cnn(
    dataset_dir: str = "polaris_dataset",
    model_path: str = "polaris_cnn.pth",
    epochs: int = 5,
    batch_size: int = 8,
    learning_rate: float = 1e-4,
):
    dataset = datasets.ImageFolder(dataset_dir, transform=transform)
    if len(dataset) < 2:
        raise ValueError("Dataset too small for CNN training.")

    loader = DataLoader(dataset, batch_size=batch_size, shuffle=True)

    model = models.mobilenet_v2(pretrained=True)
    model.classifier[1] = nn.Linear(model.last_channel, 2)
    model = model.to(DEVICE)

    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=learning_rate)
    last_loss = None

    for epoch in range(epochs):
        model.train()
        total_loss = 0.0

        for images, labels in loader:
            images, labels = images.to(DEVICE), labels.to(DEVICE)

            optimizer.zero_grad()
            outputs = model(images)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            total_loss += float(loss.item())

        last_loss = total_loss
        print(f"Epoch {epoch + 1}, Loss: {total_loss:.4f}")

    torch.save(model.state_dict(), model_path)
    print("Model saved")

    return {
        "samples": len(dataset),
        "epochs": epochs,
        "last_epoch_loss": round(last_loss or 0.0, 4),
        "model_path": model_path,
    }


if __name__ == "__main__":
    train_cnn()
