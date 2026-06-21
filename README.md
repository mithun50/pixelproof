# PixelProof

Sort your photo library into **AI-generated** vs **Real** — entirely on-device.

PixelProof scans your gallery and classifies each image using a **tiered detection
engine**, showing an honest confidence score and *why* each decision was made.
Your photos are analyzed locally and **never leave your device**.

- **Package:** `pixelproof` · **App ID:** `com.pixelproof.app`
- **Platforms:** Android (primary), iOS-ready
- **Flutter:** 3.41.x · **Dart:** 3.11.x

---

## How it works — tiered detection engine

Each image passes through up to three independent signals. Higher-precision tiers
short-circuit lower ones; the deciding signal and confidence are surfaced in the UI.

| Tier | Signal | Coverage | When it fires |
|------|--------|----------|---------------|
| 1 | **Provenance metadata** (EXIF / XMP / C2PA) | Any tool that tags its output | Near-certain |
| 2 | **SynthID-style watermark** (spectral) | Google Gemini / Imagen & similar | High precision *(experimental — off by default)* |
| 3 | **Neural classifier** (Swin ONNX) | Broad — any generator | Probabilistic |

**Fusion order:** metadata → watermark → neural. A real photo with no markers falls
through to the neural classifier, which returns an AI probability; values near the
decision boundary are reported as **Uncertain** rather than guessed.

### Tier 1 — Provenance metadata (`lib/services/metadata_service.dart`)
Scans EXIF/XMP and a bounded raw window for AI signatures: C2PA / Content Credentials,
the IPTC `DigitalSourceType = trainedAlgorithmicMedia` tag, and `Software` strings
(Stable Diffusion, Midjourney, DALL·E, Firefly, Gemini, Imagen, Flux, …). Cheap and
near-certain when present.

### Tier 2 — SynthID-style spectral watermark (`lib/services/synthid_detector.dart`)
Spread-spectrum watermarks such as Google's **SynthID** inject energy at fixed,
content-independent carrier frequencies. PixelProof detects this **independently**:
green channel → remove DC → 2D FFT → peak-to-median ratio in a low/mid-frequency
annulus. An isolated periodic peak (which natural photos essentially never produce)
flags a likely carrier. The detector is intentionally conservative to avoid false
positives.

> **Off by default.** A bare peak-to-median spectral test false-fires on ordinary
> photographs (natural 1/f spectra have strong low-frequency peaks). Reliable SynthID
> detection needs the per-resolution carrier *phase* reference codebook; until that is
> integrated, this tier abstains (`SynthIdDetector(enabled: false)`) so real photos are
> never mislabeled. The FFT/carrier code and its tests remain for when the codebook lands.

> **Detection only.** PixelProof detects watermarks; it **never removes, weakens, or
> bypasses** them. We re-implemented the detection idea from public signal-processing
> principles — no third-party watermark-removal code is included. PixelProof will not
> help disguise AI-generated content as human-made.

### Tier 3 — Neural classifier (`lib/services/classifier_service.dart`)
On-device ONNX **Swin transformer**.

- **Model:** [`onnx-community/SMOGY-Ai-images-detector-ONNX`](https://huggingface.co/onnx-community/SMOGY-Ai-images-detector-ONNX)
- **Reported accuracy:** 98.2% on its test split; out-of-domain DALL·E 90%, FLUX 83%, SD 87%, Imagen 75%.
- **I/O:** input `pixel_values` `[1,3,224,224]` float → output `logits` `[1,2]`,
  `id2label {0: artificial, 1: human}`.
- **Preprocessing:** resize 224×224 (bicubic) → ÷255 → ImageNet normalize
  (mean `[0.485,0.456,0.406]`, std `[0.229,0.224,0.225]`) → CHW.
- **License:** **CC-BY-NC-4.0 — non-commercial only.** Fine for personal/portfolio
  use; you may **not** ship it commercially without a different model.

---

## Setup

### 1. Install dependencies
```bash
flutter pub get
```

### 2. Download the model (git-ignored, ~93 MB)
The int8-quantized build is bundled at `assets/models/model.onnx`:

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
If the model is absent the neural tier abstains and the app still runs on the other tiers.

### 3. Run
```bash
flutter run
```
On first launch, grant photo access, then tap **Scan**. Results populate the
**AI / Real / Uncertain** tabs; tap any image for the full signal breakdown.

---

## Permissions
- **Android:** `READ_MEDIA_IMAGES` (API 33+), `READ_MEDIA_VISUAL_USER_SELECTED`
  (partial access, API 34+), `READ_EXTERNAL_STORAGE` (≤ API 32). `minSdk 24`
  (required by onnxruntime).
- **iOS:** `NSPhotoLibraryUsageDescription`.

All processing is on-device; the app makes **no network calls** with your images.

---

## Project structure
```
lib/
├── models/         detection_result.dart, classified_asset.dart
├── services/
│   ├── ai_classifier.dart       (interface)   classifier_service.dart (ONNX Swin)
│   ├── watermark_detector.dart  (interface)   synthid_detector.dart   (spectral)
│   ├── metadata_service.dart    (EXIF/XMP/C2PA)
│   ├── spectral.dart  fft.dart  (pure FFT + carrier analysis)
│   ├── detection_engine.dart    (tier fusion)
│   ├── gallery_service.dart  permission_service.dart  result_cache.dart (sqlite)
├── state/          scan_controller.dart  (ChangeNotifier)
├── screens/        onboarding_screen.dart  home_screen.dart  detail_sheet.dart
└── widgets/        asset_tile.dart  confidence_badge.dart
```
Tiers sit behind pure-Dart interfaces (`AiClassifier`, `WatermarkDetector`) so the
engine and its tests stay free of native dependencies.

---

## Building & releasing (CI/CD)

Two GitHub Actions workflows live in `.github/workflows/`:

| Workflow | Trigger | Does |
|----------|---------|------|
| `ci.yml` | push / PR to `main` | `flutter analyze` + `flutter test` |
| `release.yml` | push a tag `v*` | analyze + test → build **signed APK + AAB** → publish a **GitHub Release** with both artifacts attached |

### Release signing
Release builds are signed with the `alice.jks` keystore via `android/key.properties`
(git-ignored). Locally this is already configured to point at the keystore, so
`flutter build apk --release` / `flutter build appbundle --release` produce signed
artifacts. CI regenerates `key.properties` from secrets and decodes the keystore.

### One-time CI setup (GitHub repo → Settings → Secrets and variables → Actions)
Add four repository secrets:

| Secret | Value |
|--------|-------|
| `KEYSTORE_BASE64` | base64 of `alice.jks` (see command below) |
| `KEYSTORE_PASSWORD` | the keystore (store) password |
| `KEY_PASSWORD` | the key password |
| `KEY_ALIAS` | the key alias |

The password/alias values are in your keystore's `README.md` / `keystore.txt`.
Generate the base64 keystore (PowerShell) and copy it to the clipboard:

```powershell
[Convert]::ToBase64String(
  [IO.File]::ReadAllBytes("D:\Projects\InstaExam-Frontend-Production\Keystore\alice.jks")
) | Set-Clipboard
```
(macOS/Linux: `base64 -w0 alice.jks | pbcopy`)

### Cutting a release
```bash
git push                       # push your code to GitHub first
git tag v1.0.0                 # choose your version
git push origin v1.0.0         # this triggers release.yml
```
The workflow downloads the model, builds `pixelproof-v1.0.0.apk` and
`pixelproof-v1.0.0.aab`, and attaches them to a new **v1.0.0** GitHub Release with
auto-generated notes. (You can also run it manually from the Actions tab.)

> The CI clean-up step deletes the decoded keystore and `key.properties` after each
> run, and these files are git-ignored, so signing material never lands in the repo.

---

## Tests
- `test/detection_engine_test.dart` — tier fusion (6 cases)
- `test/metadata_test.dart` — provenance detection (3 cases)
- `test/spectral_test.dart` — FFT carrier detection (4 cases)
- `tool/verify_model.py` — independent ONNX model + preprocessing verification (Python)

Run them with `flutter test` (13/13 passing) and `flutter analyze` (clean).

> **Note on native assets (Windows + spaced SDK path):** Flutter's experimental
> *native-assets* hook runner fails when the Flutter SDK lives in a path containing
> a space (e.g. `C:\Users\First Last\flutter`) — it invokes the dart compiler
> unquoted. PixelProof avoids this entirely by **not depending on any native-assets
> packages**: we use `photo_manager` for permissions (no `permission_handler`) and
> `sqflite`'s `getDatabasesPath()` for storage (no `path_provider`). `onnxruntime`
> uses the classic plugin mechanism. As a result `flutter test`/`build`/`run` work
> even on a spaced SDK path.

---

## Accuracy & limitations
No AI-image detector is perfect. Benchmarks show large accuracy gaps across unseen
generators, so PixelProof presents **confidence scores, not absolute claims**, and an
**Uncertain** bucket for borderline cases. Treat results as guidance. The neural model
is strongest on diffusion-family images (SDXL/DALL·E/SD) and weaker on out-of-domain
generators (e.g. older GANs).

## Credits
- Neural model: `onnx-community/SMOGY-Ai-images-detector-ONNX` (CC-BY-NC-4.0),
  fine-tuned from `Organika/sdxl-detector`.
- SynthID watermark detection technique inspired by public research on spectral
  watermark analysis; re-implemented independently, **detection only**.
