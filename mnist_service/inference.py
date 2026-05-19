import io
import os
from pathlib import Path

import torch
import torch.nn.functional as F
from PIL import Image, UnidentifiedImageError

from model import DigitCNN


MNIST_MEAN = 0.1307
MNIST_STD = 0.3081


class DigitPredictor:
    def __init__(self, model_path=None):
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model_path = Path(model_path or os.getenv("MODEL_PATH", "models/mnist_cnn.pt"))
        self.model = self._load_model()

    @property
    def is_loaded(self):
        return self.model is not None

    def _load_model(self):
        if not self.model_path.exists():
            raise FileNotFoundError(f"Model file not found: {self.model_path}")

        model = DigitCNN().to(self.device)
        state_dict = torch.load(self.model_path, map_location=self.device)
        model.load_state_dict(state_dict)
        model.eval()
        return model

    def predict(self, image_bytes):
        tensor = self._preprocess(image_bytes)
        with torch.no_grad():
            logits = self.model(tensor)
            probabilities = F.softmax(logits, dim=1).squeeze(0).cpu()

        confidence, prediction = probabilities.max(dim=0)
        values = probabilities.tolist()

        return {
            "prediction": int(prediction.item()),
            "confidence": float(confidence.item()),
            "probabilities": {str(index): float(value) for index, value in enumerate(values)},
        }

    def _preprocess(self, image_bytes):
        try:
            image = Image.open(io.BytesIO(image_bytes))
        except UnidentifiedImageError as exc:
            raise ValueError("Uploaded file is not a valid image.") from exc

        image = image.convert("L").resize((28, 28), Image.Resampling.LANCZOS)
        pixels = torch.tensor(list(image.getdata()), dtype=torch.float32).view(1, 1, 28, 28)
        pixels = pixels / 255.0
        pixels = (pixels - MNIST_MEAN) / MNIST_STD
        return pixels.to(self.device)
