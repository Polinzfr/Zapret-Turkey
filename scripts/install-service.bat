@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "HERE=%~dp0"
set "ROOT=%HERE%..\"
set "ENGINE=%ROOT%engine"
set "PROFILES=%ROOT%profiles"
set "CONFIGF=%ROOT%config\settings.conf"
set "SVCNAME=ZapretTurkey"

echo ============================================================
echo   ZAPRET TURKEY - Hizmet Kurulumu
echo ============================================================

net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo [HATA] Bu islem yonetici yetkisi gerektirir.
    echo Sag tik - Yonetici Olarak Calistir ile tekrar deneyin.
    pause
    exit /b 1
)

if not exist "%ENGINE%\winws.exe" (
    echo [HATA] engine\winws.exe bulunamadi.
    pause
    exit /b 1
)

rem --- mevcut profili oku ---
set "CURRENT_PROFILE=stable"
if exist "%CONFIGF%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIGF%") do (
        if "%%A"=="CURRENT_PROFILE" set "CURRENT_PROFILE=%%B"
    )
)
if not exist "%PROFILES%\%CURRENT_PROFILE%.conf" (
    echo [HATA] Profil dosyasi bulunamadi: %CURRENT_PROFILE%.conf
    pause
    exit /b 1
)
set "PARGS="
set "PPORT=443"
for /f "usebackq tokens=1,* delims==" %%A in ("%PROFILES%\%CURRENT_PROFILE%.conf") do (
    if "%%A"=="ARGS" set "PARGS=%%B"
    if "%%A"=="PORT_TCP" set "PPORT=%%B"
)
if not defined PARGS (
    echo [HATA] Secili profilde ARGS satiri yok.
    pause
    exit /b 1
)

rem ONEMLI: bu dosyadaki mantik ZapretTurkey.bat'taki ENGINE_START_CORE
rem ile AYNI olmali - biri guncellenirse digeri de guncellenmeli.
rem profil dosyalarindaki ARGS satirini DEGISTIRMEZ - sadece hizmetin
rem komut satirina EKLENIR.

rem Hedef liste: desync SADECE bu listedeki adreslere uygulanir.
set "TARGET_FILE=%PROFILES%\target-hosts.txt"
if exist "%TARGET_FILE%" (
    set "PARGS=%PARGS% --hostlist="%TARGET_FILE%""
)

rem Haric tutma listesi (bilinen uyumsuzluklar - WhatsApp gibi).
set "EXCLUDE_FILE=%PROFILES%\exclude-hosts.txt"
if exist "%EXCLUDE_FILE%" (
    set "PARGS=%PARGS% --hostlist-exclude="%EXCLUDE_FILE%""
)

echo Secili profil: %CURRENT_PROFILE%
echo.

rem --- onceki calisan surumleri kapat (cakisma onlemi) ---
taskkill /F /IM winws.exe >nul 2>&1

rem --- varsa eski hizmeti kaldir, sonra yeniden kur ---
sc stop "%SVCNAME%" >nul 2>&1
sc delete "%SVCNAME%" >nul 2>&1

sc create "%SVCNAME%" binPath= "\"%ENGINE%\winws.exe\" --wf-tcp=%PPORT% %PARGS%" start= auto
if not %errorlevel%==0 (
    echo [HATA] Hizmet olusturulamadi.
    pause
    exit /b 1
)
sc description "%SVCNAME%" "Zapret Turkey - Turkiye DPI Bypass (profil: %CURRENT_PROFILE%)"
sc start "%SVCNAME%"

echo.
echo Hizmet kuruldu ve baslatildi: %SVCNAME%
echo Profil degistirdiginizde hizmeti bu ekrandan yeniden kurmaniz gerekir
echo ki yeni parametreler gecerli olsun.
pause
exit /b 0
