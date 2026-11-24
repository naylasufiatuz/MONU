@echo off
title MONU - Pasang APK ke HP
echo ============================================================
echo   MONU - MEMASANG APK TERBARU KE HP VIA ADB
echo ============================================================
echo.
set "PATH=C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools;%PATH%"

echo Memeriksa perangkat Android yang terhubung...
adb devices
echo.
echo Memasang file app-debug.apk ke perangkat...
adb install -r "%~dp0app-debug.apk"
if %ERRORLEVEL% EQU 0 (
    echo.
    echo ============================================================
    echo [SUKSES] Aplikasi MONU versi terbaru berhasil dipasang!
    echo Fitur Asisten AI (Gemini) sudah langsung aktif.
    echo ============================================================
) else (
    echo.
    echo ============================================================
    echo [CATATAN / PERANGKAT BELUM TERBACA]
    echo Pastikan:
    echo 1. HP terhubung dengan kabel USB ke Laptop.
    echo 2. USB Debugging sudah aktif di Opsi Pengembang HP.
    echo 3. Konfirmasi popup 'Izinkan USB Debugging' di layar HP.
    echo ============================================================
)
echo.
pause
