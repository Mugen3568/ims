@echo off
echo ========================================
echo    IMS App - Multi-Platform Build
echo ========================================
echo.

echo [1/4] Cleaning previous builds...
flutter clean
echo.

echo [2/4] Getting dependencies...
flutter pub get
echo.

echo [3/4] Building for Web...
flutter build web --release
echo.

echo [4/4] Build Complete!
echo.
echo ========================================
echo    Build Outputs:
echo ========================================
echo  Web: build\web\
echo ========================================
echo.
pause
