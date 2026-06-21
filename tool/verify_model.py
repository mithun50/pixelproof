"""Independent verification of the bundled ONNX model + PixelProof's preprocessing.

Replicates the Dart pipeline exactly:
  decode -> resize 224x224 (cubic) -> /255 -> ImageNet normalize -> CHW float32
and confirms model I/O shapes and label orientation (id2label {0: artificial, 1: human}).
"""
import sys
import urllib.request
import numpy as np
import onnxruntime as ort
from PIL import Image
import io

MODEL = r"C:\Projects\AI-Img\assets\models\model.onnx"
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)

def preprocess(img: Image.Image) -> np.ndarray:
    img = img.convert("RGB").resize((224, 224), Image.BICUBIC)
    arr = np.asarray(img).astype(np.float32) / 255.0  # HWC
    arr = (arr - MEAN) / STD
    chw = np.transpose(arr, (2, 0, 1))  # CHW
    return chw[None, :, :, :].astype(np.float32)  # NCHW

def softmax(x):
    e = np.exp(x - np.max(x))
    return e / e.sum()

def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    return Image.open(io.BytesIO(urllib.request.urlopen(req, timeout=60).read()))

def main():
    sess = ort.InferenceSession(MODEL, providers=["CPUExecutionProvider"])
    inp = sess.get_inputs()[0]
    out = sess.get_outputs()[0]
    print(f"INPUT  name={inp.name} shape={inp.shape} type={inp.type}")
    print(f"OUTPUT name={out.name} shape={out.shape} type={out.type}")

    tests = {
        "REAL photo (picsum #1)": "https://picsum.photos/seed/pixelproof1/640",
        "REAL photo (picsum #2)": "https://picsum.photos/seed/landscape42/640",
        "AI face (thispersondoesnotexist/StyleGAN)":
            "https://thispersondoesnotexist.com/",
    }
    for label, url in tests.items():
        try:
            img = fetch(url)
        except Exception as e:
            print(f"[skip] {label}: download failed ({e})")
            continue
        x = preprocess(img)
        logits = sess.run([out.name], {inp.name: x})[0][0]
        probs = softmax(logits)
        print(f"\n{label}")
        print(f"  logits={logits}")
        print(f"  P(artificial=idx0)={probs[0]:.4f}  P(human=idx1)={probs[1]:.4f}")
        print(f"  => verdict: {'AI' if probs[0] >= 0.5 else 'REAL'}")

if __name__ == "__main__":
    main()
