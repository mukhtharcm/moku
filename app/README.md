# Moku Flutter App

This is the shared Flutter client for Moku. It currently targets iOS, Android, and macOS from the same Dart codebase.

## Run Locally

```bash
flutter pub get
flutter run
```

Use an explicit device when switching platforms:

```bash
flutter run -d macos
flutter run -d ios
flutter run -d android
```

## Test

```bash
flutter test
```

## Build

```bash
# iOS archive/IPA; CI passes signing/export options.
flutter build ipa --release

# macOS release app bundle.
flutter build macos --release

# Android APKs.
flutter build apk --release --split-per-abi
```

## Release Notes

- iOS distribution is handled by the root `Deploy to TestFlight` GitHub Actions workflow.
- macOS distribution is handled by the root `Release macOS App` workflow and `.github/scripts/package_macos_flutter.sh`.
- Android canary builds are handled by the root `Build Android Canary` workflow.
