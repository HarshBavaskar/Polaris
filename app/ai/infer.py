import torch
from torchvision import transforms, models
from PIL import Image
import torch.nn.functional as F
import threading

DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
MODEL_PATH = "polaris_cnn.pth"

_model_lock = threading.Lock()
_model = None


def _build_model():
    model = models.mobilenet_v2(pretrained=False)
    model.classifier[1] = torch.nn.Linear(model.last_channel, 2)
    return model


def reload_cnn_model():
    global _model
    with _model_lock:
        model = _build_model()
        model.load_state_dict(torch.load(MODEL_PATH, map_location=DEVICE))
        model.eval().to(DEVICE)
        _model = model


def _ensure_model_loaded():
    global _model
    if _model is None:
        reload_cnn_model()

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor()
])

def ai_predict(image_path):
    _ensure_model_loaded()
    img = Image.open(image_path).convert("RGB")
    tensor = transform(img).unsqueeze(0).to(DEVICE)

    with _model_lock:
        with torch.no_grad():
            output = _model(tensor)
            probs = F.softmax(output, dim=1)

    return float(probs[0][1])  # probability of HIGH RISK
