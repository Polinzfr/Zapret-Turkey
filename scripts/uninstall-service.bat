@echo off
setlocal EnableExtensions
set "SVCNAME=ZapretTurkey"

echo ============================================================
echo   ZAPRET TURKEY - Hizmeti Kaldir
echo ============================================================

net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [HATA] Bu islem yonetici yetkisi gerektirir.
    echo Sag tik - Yonetici Olarak Calistir ile tekrar deneyin.
    pause
    exit /b 1
)

sc query "%SVCNAME%" >nul 2>&1
if not %errorlevel%==0 (
    echo Hizmet zaten kurulu degil.
    pause
    exit /b 0
)

sc stop "%SVCNAME%" >nul 2>&1
sc delete "%SVCNAME%"
if %errorlevel%==0 (
    echo Hizmet kaldirildi: %SVCNAME%
) else (
    echo [HATA] Hizmet kaldirilamadi.
)

echo.
echo Not: Bu islem yalnizca "%SVCNAME%" hizmetini kaldirir.
echo WinDivert surucusu baska yazilimlar tarafindan da kullanilabildigi icin
echo burada otomatik olarak silinmez. Gerekiyorsa Tanilama menusunden
echo diger WinDivert tabanli servisleri kontrol edin.
pause
exit /b 0
