@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "HERE=%~dp0"
set "ROOT=%HERE%..\"
set "ENGINE=%ROOT%engine"
set "PROFILES=%ROOT%profiles"
set "CONFIGF=%ROOT%config\settings.conf"
set "LOGS=%ROOT%logs"
set "SVCNAME=ZapretTurkey"

cls
echo ============================================================
echo   TANILAMA
echo ============================================================
echo.

rem --- yonetici ---
net session >nul 2>&1
if %errorlevel%==0 (set "R_ADMIN=EVET") else (set "R_ADMIN=HAYIR")
echo Yonetici yetkisi   : !R_ADMIN!

rem --- dosyalar ---
set "R_WINWS=EKSIK"
if exist "%ENGINE%\winws.exe" set "R_WINWS=VAR"
set "R_WD=EKSIK"
if exist "%ENGINE%\WinDivert64.sys" set "R_WD=VAR"
set "R_WDDLL=EKSIK"
if exist "%ENGINE%\WinDivert.dll" set "R_WDDLL=VAR"
echo winws.exe           : !R_WINWS!
echo WinDivert64.sys     : !R_WD!
echo WinDivert.dll       : !R_WDDLL!

rem --- profil ---
set "CURRENT_PROFILE=stable"
if exist "%CONFIGF%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIGF%") do (
        if "%%A"=="CURRENT_PROFILE" set "CURRENT_PROFILE=%%B"
        if "%%A"=="DNS_MODE" set "R_DNSMODE=%%B"
    )
)
echo Secili profil       : !CURRENT_PROFILE!
echo DNS modu (uygulama) : !R_DNSMODE!

rem --- calisma durumu ---
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (set "R_RUN=CALISIYOR") else (set "R_RUN=CALISMIYOR")
echo winws durumu        : !R_RUN!

sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (set "R_SVC=KURULU") else (set "R_SVC=KURULU DEGIL")
echo Hizmet durumu       : !R_SVC!

rem --- olasi cakisma: baska WinDivert tabanli servisler ---
echo.
echo --- WinDivert tabanli olasi servisler ---
set "R_CONFLICT=YOK"
for %%S in (WinDivert WinDivert14 GoodbyeDPI) do (
    sc query "%%S" >nul 2>&1
    if !errorlevel!==0 (
        echo   [!] Bulundu: %%S  ^(bu Zapret Turkey disinda baska bir WinDivert
        echo       tabanli arac olabilir - ayni anda calistirmayin^)
        set "R_CONFLICT=VAR"
    )
)
if "!R_CONFLICT!"=="YOK" echo   Bilinen cakisan servis bulunamadi.

rem --- IPv4/IPv6 ---
echo.
echo --- Baglanti ---
ipconfig | find /I "IPv4" >nul
if %errorlevel%==0 (set "R_IPV4=VAR") else (set "R_IPV4=YOK")
ipconfig | find /I "IPv6" >nul
if %errorlevel%==0 (set "R_IPV6=VAR") else (set "R_IPV6=YOK")
echo IPv4 adresi         : !R_IPV4!
echo IPv6 adresi         : !R_IPV6!

rem --- HTTPS/uygulama erisim testi ---
echo.
echo --- Baglanti testleri (curl ile) ---
where curl >nul 2>&1
if %errorlevel%==0 (
    for %%D in (discord.com:Discord www.roblox.com:Roblox store.steampowered.com:Steam cloudflare.com:HTTPS_genel) do (
        for /f "tokens=1,2 delims=:" %%X in ("%%D") do (
            curl -s -o nul --max-time 6 "https://%%X"
            if !errorlevel!==0 (
                echo   %%Y : OK
                set "R_%%Y=OK"
            ) else (
                echo   %%Y : BASARISIZ
                set "R_%%Y=BASARISIZ"
            )
        )
    )
) else (
    echo   curl.exe bulunamadi, baglanti testleri atlandi.
    set "R_Discord=BILINMIYOR"
    set "R_Roblox=BILINMIYOR"
    set "R_Steam=BILINMIYOR"
    set "R_HTTPS_genel=BILINMIYOR"
)

echo.
echo ============================================================
echo.
choice /c YN /n /m "Tanilama raporu (sanitized TXT) olusturulsun mu? [Y/N]: "
if not errorlevel 2 (
    if not exist "%LOGS%" mkdir "%LOGS%" >nul 2>&1
    set "REPORT=%LOGS%\diagnostic-report.txt"
    > "!REPORT!" echo Zapret Turkey - Tanilama Raporu
    >> "!REPORT!" echo Tarih: %date% %time%
    >> "!REPORT!" echo.
    >> "!REPORT!" echo Profil            : !CURRENT_PROFILE!
    >> "!REPORT!" echo DNS modu          : !R_DNSMODE!
    >> "!REPORT!" echo Yonetici          : !R_ADMIN!
    >> "!REPORT!" echo winws durumu      : !R_RUN!
    >> "!REPORT!" echo Hizmet durumu     : !R_SVC!
    >> "!REPORT!" echo IPv4              : !R_IPV4!
    >> "!REPORT!" echo IPv6              : !R_IPV6!
    >> "!REPORT!" echo WinDivert cakisma : !R_CONFLICT!
    >> "!REPORT!" echo Discord           : !R_Discord!
    >> "!REPORT!" echo Roblox            : !R_Roblox!
    >> "!REPORT!" echo Steam             : !R_Steam!
    >> "!REPORT!" echo HTTPS (genel)     : !R_HTTPS_genel!
    >> "!REPORT!" echo.
    >> "!REPORT!" echo Not: Bu raporda gercek IP adresi, MAC adresi, bilgisayar adi,
    >> "!REPORT!" echo kullanici adi veya dosya yollari bilerek YER ALMAZ.
    >> "!REPORT!" echo ISS ^(internet servis saglayici^) bilgisini biliyorsaniz GitHub
    >> "!REPORT!" echo Issue'ya eklerken elle belirtebilirsiniz.
    echo Rapor olusturuldu: !REPORT!
)
exit /b 0
