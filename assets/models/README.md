# Model assets

The app loads `assets/models/model.onnx` at runtime (see `ClassifierService`).

**Model:** `onnx-community/SMOGY-Ai-images-detector-ONNX` (Swin transformer)
- Source: https://huggingface.co/onnx-community/SMOGY-Ai-images-detector-ONNX
- License: **CC-BY-NC-4.0 (non-commercial only)**
- Task: classify images as AI-generated (`artificial`, idx 0) vs Real (`human`, idx 1)
- Input: `pixel_values` `[batch, 3, 224, 224]` float32
- Output: `logits` `[batch, 2]`
- Preprocessing: resize 224×224 (bicubic) → /255 → ImageNet normalize
  (mean `[0.485, 0.456, 0.406]`, std `[0.229, 0.224, 0.225]`)

## Bundled variant

We bundle the **int8 quantized** build (`model_quantized.onnx`, ~93 MB) — the best
size/accuracy trade-off for on-device CPU inference. The full fp32 build is ~352 MB.

The `.onnx` file is **git-ignored** (too large to commit). Download it during setup:

```powershell
# Windows PowerShell
Invoke-WebRequest `
  -Uri "https://huggingface.co/onnx-community/SMOGY-Ai-images-detector-ONNX/resolve/main/onnx/model_quantized.onnx?download=true" `
  -OutFile "assets/models/model.onnx"
```

```bash
# macOS / Linux
curl -L -o assets/models/model.onnx \
  "https://huggingface.co/onnx-community/SMOGY-Ai-images-detector-ONNX/resolve/main/onnx/model_quantized.onnx?download=true"
```

If the file is missing, the neural tier abstains gracefully and the app still runs
(metadata / SynthID tiers continue to work).
