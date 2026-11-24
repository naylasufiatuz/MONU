@echo off
title MONU - Server Web / iOS (iPhone & iPad)
echo ============================================================
echo   MONU (DiHutan) - SERVER AKSES & INSTALL UNTUK iOS / iPHONE
echo ============================================================
echo.
cd /d "%~dp0"

echo IP Laptop Anda di jaringan Wi-Fi: 10.218.10.147
echo.
echo ============================================================
echo   CARA DOWNLOAD & PASANG DI iPHONE (iOS):
echo ============================================================
echo 1. Pastikan iPhone terhubung ke jaringan Wi-Fi yang sama.
echo 2. Buka browser Safari di iPhone.
echo 3. Masukkan alamat:
echo    http://10.218.10.147:8080/
echo.
echo 4. Di Safari iPhone, tekan tombol 'Share' (ikon kotak panah ke atas di bawah).
echo 5. Gulir ke bawah dan pilih 'Add to Home Screen' (Tambahkan ke Layar Utama).
echo 6. Tekan 'Add' / 'Tambah' di pojok kanan atas.
echo.
echo Selesai! Ikon aplikasi MONU akan terpasang di layar utama iPhone
echo dan bisa dibuka layaknya aplikasi native (Full Screen, tanpa bar URL).
echo ============================================================
echo.
echo Server sedang berjalan di port 8080...
echo Jangan tutup jendela ini selama menggunakan aplikasi di iPhone.
echo.
python -m http.server 8080 --directory build/web
pause
