@echo off
title MONU - Build APK Android
echo ============================================================
echo   MONU (DiHutan) - MEMBANGUN APK ANDROID UNTUK HP
echo ============================================================
echo.
cd /d "%~dp0"
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=C:\Program Files\Android\Android Studio\jbr\bin;C:\Users\Lenovo\develop\flutter\bin;%PATH%"

echo [1/2] Mengambil dependensi Flutter...
call flutter pub get

echo.
echo [2/2] Mengompilasi APK (Mode Debug untuk Sideload Langsung ke HP)...
call flutter build apk --debug

echo.
echo ============================================================
if exist "build\app\outputs\flutter-apk\app-debug.apk" (
    echo [SUKSES] File APK berhasil dibuat!
    echo Lokasi File:
    echo %~dp0build\app\outputs\flutter-apk\app-debug.apk
    echo.
    echo Cara Pasang di HP:
    echo 1. Salin file 'app-debug.apk' ke HP (Kabel USB, WA Web, atau Google Drive)
    echo 2. Buka file APK di HP lalu pilih 'Install'
    echo 3. Aplikasi langsung tersambung ke Supabase Cloud!
) else (
    echo [INFO] Periksa log output build di atas.
)
echo ============================================================
echo.
pause
