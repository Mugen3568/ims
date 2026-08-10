@echo off
cls
echo ========================================
echo    IMS APP - MULTI-PLATFORM LAUNCHER
echo ========================================
echo.
echo Select Platform:
echo.
echo [1] Web (Chrome) - FASTEST, RECOMMENDED
echo [2] Windows Desktop
echo [3] Android (Requires emulator)
echo [4] Check Available Devices
echo [5] Build All Platforms
echo [6] Exit
echo.
echo ========================================
set /p choice="Enter your choice (1-6): "

if "%choice%"=="1" goto web
if "%choice%"=="2" goto windows
if "%choice%"=="3" goto android
if "%choice%"=="4" goto devices
if "%choice%"=="5" goto build
if "%choice%"=="6" goto end

:web
echo.
echo ========================================
echo    Launching on Web (Chrome)...
echo ========================================
echo.
flutter run -d chrome
goto end

:windows
echo.
echo ========================================
echo    Launching on Windows Desktop...
echo ========================================
echo.
flutter run -d windows
goto end

:android
echo.
echo ========================================
echo    Launching on Android...
echo ========================================
echo.
echo Checking for Android devices...
flutter devices
echo.
echo If no Android device found, run:
echo   flutter emulators
echo   flutter emulators --launch [emulator_id]
echo.
pause
flutter run -d android
goto end

:devices
echo.
echo ========================================
echo    Available Devices:
echo ========================================
flutter devices
echo.
pause
goto end

:build
echo.
echo ========================================
echo    Building All Platforms...
echo ========================================
echo.
echo [1/5] Cleaning previous builds...
flutter clean
echo.
echo [2/5] Getting dependencies...
flutter pub get
echo.
echo [3/5] Building Web...
flutter build web --release
echo.
echo [4/5] Checking Android setup...
flutter doctor
echo.
echo [5/5] Build Complete!
echo.
echo ========================================
echo    Build Outputs:
echo ========================================
echo  Web: build\web\
echo.
echo To build Android:
echo   flutter build apk --release
echo.
echo To build Windows:
echo   flutter build windows --release
echo.
echo ========================================
pause
goto end

:end
echo.
echo Thank you for using IMS App Launcher!
echo.
pause
