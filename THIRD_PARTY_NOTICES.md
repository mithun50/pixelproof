# Third-Party Notices

PixelProof itself is proprietary (see [LICENSE](LICENSE)). It incorporates the
following third-party components, each under its own license. These notices are
provided for attribution and compliance.

## Neural model

- **`onnx-community/SMOGY-Ai-images-detector-ONNX`** (Swin transformer),
  fine-tuned from `Organika/sdxl-detector`.
  - License: **CC-BY-NC-4.0 (Creative Commons Attribution-NonCommercial 4.0)**.
  - **Non-commercial use only.** Commercial distribution of PixelProof requires
    replacing this model with an appropriately licensed alternative.
  - Source: https://huggingface.co/onnx-community/SMOGY-Ai-images-detector-ONNX

## Flutter / Dart packages

Licenses as published on pub.dev (most are BSD-3-Clause / MIT / Apache-2.0):

| Package | Typical license |
|---------|-----------------|
| `onnxruntime` | MIT |
| `photo_manager`, `photo_manager_image_provider` | Apache-2.0 |
| `image` | Apache-2.0 / MIT |
| `provider` | MIT |
| `sqflite` | BSD / MIT |
| `path` | BSD-3-Clause |
| `crypto` | BSD-3-Clause |
| `exif` | BSD |
| `flutter_local_notifications` | BSD-3-Clause |
| `flutter_background_service` | MIT |
| `image_picker` | Apache-2.0 |

Run `flutter pub deps` for the full resolved dependency tree, and see each
package's page on https://pub.dev for its exact license text.

## Detection techniques

- The SynthID-style spectral watermark **detection** approach was re-implemented
  independently from public signal-processing principles. No third-party
  watermark code is included, and PixelProof performs **detection only** — it
  never removes or bypasses watermarks.
