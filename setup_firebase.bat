@echo off
cls
echo ========================================
echo    IMS APP - FIREBASE SETUP WIZARD
echo ========================================
echo.
echo This script will guide you through:
echo 1. Installing Firebase CLI
echo 2. Logging into Firebase
echo 3. Configuring multi-platform support
echo 4. Deploying to Firebase Hosting
echo.
echo ========================================
echo.
pause

echo.
echo ========================================
echo    Step 1: Checking Node.js...
echo ========================================
echo.
node --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed!
    echo.
    echo Please install Node.js from:
    echo https://nodejs.org/
    echo.
    echo After installation, run this script again.
    pause
    exit /b 1
) else (
    echo [OK] Node.js is installed
    node --version
)

echo.
echo ========================================
echo    Step 2: Installing Firebase CLI...
echo ========================================
echo.
firebase --version >nul 2>&1
if %errorlevel% neq 0 (
    echo Installing Firebase CLI globally...
    echo This may take 2-3 minutes...
    npm install -g firebase-tools
) else (
    echo [OK] Firebase CLI already installed
    firebase --version
)

echo.
echo ========================================
echo    Step 3: Firebase Login...
echo ========================================
echo.
echo A browser window will open for authentication.
echo Please login with: mugenbanana6@gmail.com
echo.
pause
firebase login

echo.
echo ========================================
echo    Step 4: FlutterFire Configuration...
echo ========================================
echo.
echo Configuring Firebase for all platforms...
echo.
echo IMPORTANT: When prompted, use SPACEBAR to select:
echo   [X] android
echo   [X] ios
echo   [X] web
echo.
echo Then press ENTER to continue.
echo.
pause
flutterfire configure --project=ims-app-8e988

echo.
echo ========================================
echo    Step 5: Firebase Hosting Setup...
echo ========================================
echo.
echo Initializing Firebase Hosting...
echo.
echo When prompted:
echo   - Public directory: build\web
echo   - Single-page app: Yes
echo   - Automatic builds: No
echo   - Overwrite index.html: No
echo.
pause
firebase init hosting

echo.
echo ========================================
echo    Step 6: Build and Deploy Web App...
echo ========================================
echo.
set /p deploy="Build and deploy to Firebase Hosting now? (y/n): "
if /i "%deploy%"=="y" (
    echo.
    echo Building production web version...
    flutter clean
    flutter pub get
    flutter build web --release
    
    echo.
    echo Deploying to Firebase Hosting...
    firebase deploy --only hosting
    
    echo.
    echo ========================================
    echo    DEPLOYMENT COMPLETE!
    echo ========================================
    echo.
    echo Your app is now live at:
    echo https://ims-app-8e988.web.app
    echo https://ims-app-8e988.firebaseapp.com
    echo.
) else (
    echo.
    echo Skipping deployment. You can deploy later with:
    echo   flutter build web --release
    echo   firebase deploy --only hosting
    echo.
)

echo.
echo ========================================
echo    FIREBASE SETUP COMPLETE!
echo ========================================
echo.
echo Next steps:
echo 1. Enable Authentication in Firebase Console:
echo    https://console.firebase.google.com/project/ims-app-8e988/authentication
echo.
echo 2. Create Firestore Database:
echo    https://console.firebase.google.com/project/ims-app-8e988/firestore
echo.
echo 3. Apply Security Rules (see FIRESTORE_STRUCTURE.md)
echo.
echo 4. Test your app:
echo    flutter run -d chrome
echo.
echo ========================================
pause
