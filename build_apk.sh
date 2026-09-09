#!/usr/bin/env bash
set -e

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not installed or not in PATH."
  exit 1
fi

if [ ! -d android ]; then
  flutter create --platforms=android .
fi

flutter pub get
flutter test
flutter build apk --release

echo
echo "APK created at:"
echo "build/app/outputs/flutter-apk/app-release.apk"
