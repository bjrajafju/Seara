@echo off
setlocal

echo ==========================
echo SEARA ANDROID RELEASE BUILD
echo ==========================

set ROOT=C:\Users\Asus\Documents\GitHub\Seara
set PROJECT_DIR=%ROOT%\Seara
set VERSION=2.0.0

echo PROJECT DIR:
echo %PROJECT_DIR%

pushd "%PROJECT_DIR%"

echo ==========================
echo CLEAN + GET DEPENDENCIES
echo ==========================

call flutter clean
call flutter pub get

echo ==========================
echo BUILD APK
echo ==========================

call flutter build apk --release

if %errorlevel% neq 0 (
  echo BUILD FAILED
  popd
  pause
  exit /b
)

set APK_PATH=%PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk

if not exist "%APK_PATH%" (
  echo ERROR: APK NOT FOUND
  popd
  pause
  exit /b
)

echo ==========================
echo PREPARING APK NAME
echo ==========================

set FINAL_APK=%PROJECT_DIR%\build\app\outputs\flutter-apk\Seara.apk

copy /Y "%APK_PATH%" "%FINAL_APK%"

if %errorlevel% neq 0 (
  echo ERROR: APK COPY FAILED
  popd
  pause
  exit /b
)

if not exist "%FINAL_APK%" (
  echo ERROR: RENAMED APK NOT FOUND
  popd
  pause
  exit /b
)

echo ==========================
echo CREATING GITHUB RELEASE
echo ==========================

gh release create "%VERSION%" "%FINAL_APK%" ^
--title "Seara %VERSION%" ^
--notes "Android release %VERSION%"

if %errorlevel% neq 0 (
  echo RELEASE FAILED
  popd
  pause
  exit /b
)

popd

echo ==========================
echo DONE
echo ==========================

pause
