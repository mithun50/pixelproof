# Security Policy

## Privacy posture

PixelProof is **privacy-first and offline**. All image analysis (metadata,
spectral, and neural inference) runs **on-device**. The app makes **no network
calls with your images**, and photos never leave the device. The only network
access in the project is at *build/release time* (downloading the ML model
asset and Flutter dependencies) — never at runtime with user data.

## Supported versions

| Version | Supported |
|---------|-----------|
| Latest release (`v*`) | ✅ |
| Older releases | ❌ |

Only the most recent release receives security fixes.

## Reporting a vulnerability

**Please do not open a public issue for security vulnerabilities.**

Report privately using GitHub's **"Report a vulnerability"** button under the
repository's **Security** tab
(https://github.com/mithun50/pixelproof/security/advisories/new), or email the
maintainer at **mithungowda.b7411@gmail.com**.

Please include:
- a description of the issue and its impact,
- steps to reproduce (proof-of-concept if possible),
- affected version / commit.

You can expect an acknowledgement within **5 business days**. Please allow
reasonable time for a fix before any public disclosure (coordinated disclosure).

## Handling of signing material

Release signing keys are **never** committed. They are stored as encrypted
GitHub Actions secrets and decoded only inside CI, then deleted at the end of
each run. `key.properties` and `*.jks`/`*.keystore` files are git-ignored.
