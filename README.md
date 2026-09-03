# Azula — iOS 27

Azula patches decrypted iOS applications by injecting one or more compatible arm64 dylibs and exporting a new unsigned IPA for your normal sideload signer.

## Current target

- iOS 27
- Modern arm64 iPhones
- Xcode 27 real-device builds
- Unsigned IPA output for normal sideload signing

## Features

- Adaptive iPhone UI with first-launch onboarding
- Fire/gunmetal visual design and AppIcon
- Import a decrypted `.ipa` from Files
- Import one or multiple `.dylib` files from Files
- Files-provider compatibility: IPA/dylib pickers accept generic file data, then strictly validate the `.ipa` or `.dylib` extension after selection so valid dylibs are not grayed out by incorrect provider UTIs
- Security-scoped imports are copied into Azula's sandbox before patching; originals are not modified
- Stages injected libraries under the target app's `Frameworks` directory
- Optional ElleKit compatibility for common Substrate/libhooker dependency paths
- Phase-based patch activity and technical log
- Exports an unsigned patched IPA through the iOS share sheet

## Usage

1. Install and open Azula.
2. Complete or skip onboarding.
3. Choose a decrypted IPA.
4. Choose one or more dylibs.
5. Leave ElleKit compatibility enabled when the selected tweak requires supported hook-path localization.
6. Tap **Build Patched IPA**.
7. Share the result to your normal sideload signer and sign all embedded executable code before installing.

## Notes

Azula does not sign or install the resulting IPA itself. A target executable still needs enough Mach-O header space for the requested load commands, and injected libraries must themselves be compatible with the target app and device architecture.

## Credits

- Original Azula project by Paisseon
- ElleKit by Evelyneee / ElleKit contributors
