# Contributing to PixelProof

Thank you for your interest in PixelProof!

> **Important:** PixelProof is **proprietary software** (see [LICENSE](LICENSE)).
> The source is published for reference and evaluation. Contributions are
> welcome but are accepted **at the maintainer's discretion**, and by
> submitting a contribution you agree that the maintainer, **Mithun Gowda B**,
> may use it under the project's proprietary license without restriction or
> obligation.

## Before you start

- For anything non-trivial, **open an issue first** to discuss the change.
- For security issues, **do not** open a public issue — see [SECURITY.md](SECURITY.md).
- Be respectful — see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Development setup

1. Install Flutter 3.41.x (Dart 3.11.x).
2. `flutter pub get`
3. Download the model (git-ignored) — see [`assets/models/README.md`](assets/models/README.md).
4. Run: `flutter run`

> **Windows note:** install the Flutter SDK at a path **without spaces**. The
> project deliberately avoids native-assets packages, but a spaced SDK path can
> still break Flutter's experimental hook runner for other dependencies.

## Quality gates (run before opening a PR)

```bash
flutter analyze   # must be clean
flutter test      # all tests must pass
```

- Match the existing style and architecture (tiers sit behind the pure-Dart
  `AiClassifier` / `WatermarkDetector` interfaces; keep the detection engine
  free of native dependencies so it stays unit-testable).
- Add or update tests for any behavior change.
- Keep commits focused and write clear messages.

## Pull requests

- Target the `main` branch.
- Describe **what** changed, **why**, and **how you tested** it.
- Ensure CI (`analyze` + `test`) is green.

## What not to commit

- Secrets, keystores (`*.jks`/`*.keystore`), `key.properties`
- The ML model binary (`assets/models/*.onnx`) — it is downloaded at setup
