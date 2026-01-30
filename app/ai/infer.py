import torch
from torchvision import transforms, models
from PIL import Image
import torch.nn.functional as F

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"

model = models.mobilenet_v2(pretrained=False)
model.classifier[1] = torch.nn.Linear(model.last_channel, 2)
model.load_state_dict(torch.load("polaris_cnn.pth", map_location=DEVICE))
model.eval().to(DEVICE)

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor()
])

def ai_predict(image_path):
    img = Image.open(image_path).convert("RGB")
    tensor = transform(img).unsqueeze(0).to(DEVICE)

    with torch.no_grad():
        output = model(tensor)
        probs = F.softmax(output, dim=1)

    return float(probs[0][1])  # probability of HIGH RISK
