# Azula — iOS 27

[![Build iOS 27 Unsigned IPA](https://github.com/NightVibes33/Azula/actions/workflows/build-ios27-unsigned.yml/badge.svg?branch=main)](https://github.com/NightVibes33/Azula/actions/workflows/build-ios27-unsigned.yml)

Azula is an iPhone utility for patching **decrypted iOS apps** with one or more compatible dynamic libraries and exporting a new **unsigned IPA** for your normal sideload signer.

## Current release

- **Version:** 2.1.6
- **Build:** 9
- **Primary branch:** `main`
- **Target:** iOS 27
- **Device family:** iPhone
- **Architecture:** arm64
- **Build environment:** Xcode 27 / iOS 27 SDK

## What Azula does

Azula provides a native iPhone workflow for:

1. Selecting a decrypted `.ipa`.
2. Selecting one or more `.dylib` files.
3. Copying the selected files into Azula's sandbox without modifying the originals.
4. Extracting the target app.
5. Staging injected libraries inside the app's `Frameworks` directory.
6. Injecting the requested Mach-O load commands.
7. Optionally localizing common hook-library dependencies for bundled ElleKit compatibility.
8. Repacking the app as a new unsigned IPA.
9. Sharing the result to a sideload signer.

## File importing

Azula uses **UIKit's `UIDocumentPickerViewController` directly** instead of SwiftUI `fileImporter`.

The Files browser is opened without a restrictive UTI filter so provider-specific type metadata cannot prevent an otherwise valid file from being tapped. After UIKit returns the selected URL, Azula performs its own validation:

### IPA validation

- Filename must end in `.ipa`.
- File must have a valid ZIP/IPA signature.

### dylib validation

- Filename must end in `.dylib`.
- File must begin with a supported Mach-O or fat Mach-O magic value.
- Multiple dylibs can be selected in one picker session.

The app still declares the standard imported document identifiers:

- `com.apple.itunes.ipa`
- `com.apple.mach-o-dylib`

These declarations describe the supported document formats, while actual picker selection is handled through the UIKit delegate path.

## UI

The iOS 27 build includes:

- First-launch onboarding
- Adaptive portrait and landscape layout
- Fire / gunmetal visual system
- Target IPA and dylib workspace cards
- ElleKit compatibility control
- Phase-based patch activity
- Technical patch log
- Dedicated success and failure states
- Share-to-signer flow
- Dynamic Type and VoiceOver support

## Requirements

### Target IPA

The target app must already be **decrypted**. Azula does not decrypt App Store binaries.

### Injected libraries

Injected dylibs must be compatible with the target application and device architecture. Azula validates the container/signature format, but that does not guarantee the library itself is logically compatible with the target app.

### Signing

Azula does **not** sign or install the finished IPA. Your sideload signer must sign the main app executable and all embedded executable code before installation.

## ElleKit compatibility

The build bundles the current ElleKit arm64/arm64e library used by the project CI. When compatibility is enabled, Azula can rewrite supported Substrate/libhooker/ElleKit dependency paths so the patched application can load the bundled compatibility library from its own app bundle.

This does not make every jailbreak tweak usable in a normal sideloaded application. Tweaks that depend on SpringBoard, privileged jailbreak services, unsupported entitlements, kernel access, or other jailbreak-only runtime facilities can still fail.

## Known limitations

- The target executable must have enough Mach-O header space for the requested load commands.
- Encrypted App Store binaries are not supported as normal patch targets.
- Libraries must contain compatible device architecture code.
- A successful patch does not guarantee the injected tweak is compatible with the target app's runtime behavior.
- The output is unsigned and requires external signing.
- Azula is currently configured for iPhone / arm64 / iOS 27 rather than the older cross-platform targets from upstream Azula.

## Building

The repository uses XcodeGen and GitHub Actions.

The CI workflow:

1. Verifies Xcode 27 and the iOS 27 SDK.
2. Prepares ZIPFoundation.
3. Bundles ElleKit.
4. Validates the UIKit document-picker implementation.
5. Generates `Azula.xcodeproj` from `project.yml`.
6. Builds an unsigned arm64 real-device application.
7. Validates the resulting app bundle and Info.plist.
8. Packages `Payload/Azula.app` into an unsigned IPA.
9. Uploads the IPA as a GitHub Actions artifact.

The authoritative workflow is:

`.github/workflows/build-ios27-unsigned.yml`

## Branches

- `main` — current iOS 27 release line
- `ios27-final-exact` — retained development/history branch used while stabilizing the iOS 27 build

Older fork branches may contain previous experiments and are not the authoritative release source.

## Credits

- **Azula** — original project by Paisseon
- **ElleKit** — Evelyneee and contributors
- **ZIPFoundation** — weichsel and contributors

## Disclaimer

Use Azula only with applications and binaries you are authorized to modify. You are responsible for signing, distribution, compatibility, and compliance with the licenses and terms that apply to the software you patch.
