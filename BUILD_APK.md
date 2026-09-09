# Build the Android APK

## Easiest: GitHub Actions

1. Create a new GitHub repository.
2. Upload all files from this project to the repository.
3. Open the **Actions** tab.
4. Select **Build Android APK**.
5. Click **Run workflow**.
6. When it finishes, open the completed workflow run.
7. Under **Artifacts**, download **domino-all-fives-apk**.
8. Extract it to get `app-release.apk`.
9. Copy that APK to your Android phone and install it.

The included workflow automatically:
- installs Java
- installs Flutter
- creates the Android platform folder if it is missing
- gets packages
- runs tests
- builds a release APK
- uploads the APK as a downloadable artifact

## Build on your own computer

### Windows
Install Flutter and Android Studio, then double-click or run:

`build_apk_windows.bat`

### macOS / Linux
Install Flutter and Android SDK, then run:

`./build_apk.sh`

The APK output will be:

`build/app/outputs/flutter-apk/app-release.apk`
