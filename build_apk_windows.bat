@echo off
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter is not installed or not in PATH.
  exit /b 1
)

if not exist android (
  flutter create --platforms=android .
)

flutter pub get
if errorlevel 1 exit /b 1

flutter test
if errorlevel 1 exit /b 1

flutter build apk --release
if errorlevel 1 exit /b 1

echo.
echo APK created at:
echo build\app\outputs\flutter-apk\app-release.apk
