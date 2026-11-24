@echo off
title MONU - Install Langsung ke HP via USB
echo ============================================================
echo   MONU (DiHutan) - INSTALL & RUN LANGSUNG KE HP
echo ============================================================
echo.
cd /d "%~dp0"
set "JAVA_HOME=C:\Program Files\Android\Android Studio\jbr"
set "PATH=C:\Program Files\Android\Android Studio\jbr\bin;C:\Users\Lenovo\develop\flutter\bin;%PATH%"

echo Pastikan:
echo 1. HP terhubung dengan kabel data ke laptop.
echo 2. 'USB Debugging' di HP sudah diaktifkan (Opsi Pengembang).
echo.
echo Memeriksa perangkat yang terhubung...
call flutter devices
echo.
echo Menjalankan aplikasi ke HP...
call flutter run
pause
