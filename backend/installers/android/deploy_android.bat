@echo off
setlocal
echo ==========================
echo SEARA ANDROID BUILD START
echo ==========================
set ROOT=C:\Users\Asus\Documents\GitHub\Seara
set PROJECT_DIR=%ROOT%\Seara
echo PROJECT DIR:
echo %PROJECT_DIR%
echo ==========================
echo START BUILD
echo ==========================
pushd "%PROJECT_DIR%"
echo NOW IN:
cd
echo CLEAN CACHE (SAFE)
call flutter clean
echo GET DEPENDENCIES
call flutter pub get
echo BUILDING APK...
call flutter build apk --release
echo ERRORLEVEL AFTER BUILD = %errorlevel%
if %errorlevel% neq 0 (
  echo BUILD FAILED
  popd
  pause
  exit /b
)
echo ==========================
echo COPY APK
echo ==========================
set APK_SOURCE=%PROJECT_DIR%\build\app\outputs\flutter-apk\app-release.apk
set APK_DEST=%ROOT%\backend\installers\android\Seara.apk
echo SOURCE:
echo %APK_SOURCE%
echo DEST:
echo %APK_DEST%
if not exist "%APK_SOURCE%" (
  echo ERROR: APK NOT FOUND
  popd
  pause
  exit /b
)
copy /Y "%APK_SOURCE%" "%APK_DEST%"
if %errorlevel% neq 0 (
  echo ERROR: COPY FAILED
  popd
  pause
  exit /b
)
popd
echo ==========================
echo DONE
echo ==========================
pause
