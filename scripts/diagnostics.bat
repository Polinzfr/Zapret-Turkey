@echo off
setlocal EnableExtensions EnableDelayedExpansion
set "HERE=%~dp0"
set "ROOT=%HERE%..\"
set "ENGINE=%ROOT%engine"
set "PROFILES=%ROOT%profiles"
set "CONFIGF=%ROOT%config\settings.conf"
set "LOGS=%ROOT%logs"
set "SVCNAME=ZapretTurkey"

call "%HERE%lang-load.bat"

cls
echo ============================================================
echo   %L_DIAG_TITLE%
echo ============================================================
echo.

rem --- admin ---
net session >nul 2>&1
if %errorlevel%==0 (set "R_ADMIN=Y") else (set "R_ADMIN=N")
if "!R_ADMIN!"=="Y" (set "R_ADMIN_TXT=%L_DEBUG_YES%") else (set "R_ADMIN_TXT=%L_DEBUG_NO%")
echo %L_DEBUG_ADMIN_LABEL% !R_ADMIN_TXT!

rem --- files ---
set "R_WINWS=N"
if exist "%ENGINE%\winws.exe" set "R_WINWS=Y"
set "R_WD=N"
if exist "%ENGINE%\WinDivert64.sys" set "R_WD=Y"
set "R_WDDLL=N"
if exist "%ENGINE%\WinDivert.dll" set "R_WDDLL=Y"
if "!R_WINWS!"=="Y" (set "R_WINWS_TXT=%L_DIAG_STATUS_PRESENT%") else (set "R_WINWS_TXT=%L_DIAG_STATUS_MISSING%")
if "!R_WD!"=="Y" (set "R_WD_TXT=%L_DIAG_STATUS_PRESENT%") else (set "R_WD_TXT=%L_DIAG_STATUS_MISSING%")
if "!R_WDDLL!"=="Y" (set "R_WDDLL_TXT=%L_DIAG_STATUS_PRESENT%") else (set "R_WDDLL_TXT=%L_DIAG_STATUS_MISSING%")
echo %L_DIAG_ENGINE_LABEL% !R_WINWS_TXT!
echo %L_DIAG_WD_SYS_LABEL% !R_WD_TXT!
echo %L_DIAG_WD_DLL_LABEL% !R_WDDLL_TXT!

rem --- profile ---
set "CURRENT_PROFILE=stable"
if exist "%CONFIGF%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIGF%") do (
        if "%%A"=="CURRENT_PROFILE" set "CURRENT_PROFILE=%%B"
        if "%%A"=="DNS_MODE" set "R_DNSMODE=%%B"
    )
)
echo %L_DIAG_PROFILE_LABEL% !CURRENT_PROFILE!
echo !L_DIAG_DNSMODE_LABEL! !R_DNSMODE!

rem --- running status ---
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (set "R_RUN=Y") else (set "R_RUN=N")
if "!R_RUN!"=="Y" (set "R_RUN_TXT=%L_DEBUG_WINWS_RUNNING%") else (set "R_RUN_TXT=%L_DEBUG_WINWS_NOT_RUNNING%")
echo %L_DEBUG_WINWS_STATUS_LABEL% !R_RUN_TXT!

sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (set "R_SVC=Y") else (set "R_SVC=N")
if "!R_SVC!"=="Y" (set "R_SVC_TXT=%L_SVC_INSTALLED%") else (set "R_SVC_TXT=%L_SVC_NOT_INSTALLED%")
echo %L_DEBUG_SVC_STATUS_LABEL% !R_SVC_TXT!

rem --- olasi cakisma: baska WinDivert tabanli servisler ---
echo.
echo %L_DIAG_CONFLICT_SECTION%
set "R_CONFLICT=N"
rem Genel "WinDivert" servisi Zapret'in KENDI surucusudur: winws veya
rem Zapret Turkey servisi calisirken cakisma sayilmaz (yaniltici olurdu).
for %%S in (WinDivert WinDivert14 GoodbyeDPI) do (
    set "SKIP_CF=0"
    if /i "%%S"=="WinDivert" if "!R_RUN!"=="Y" set "SKIP_CF=1"
    if /i "%%S"=="WinDivert" if "!R_SVC!"=="Y" set "SKIP_CF=1"
    if "!SKIP_CF!"=="0" (
        sc query "%%S" >nul 2>&1
        if !errorlevel!==0 (
            echo   * !L_DIAG_CONFLICT_FOUND! %%S
            echo       !L_DIAG_CONFLICT_HINT!
            set "R_CONFLICT=Y"
        )
    )
)
if "!R_CONFLICT!"=="N" echo   %L_DIAG_CONFLICT_NONE%
if "!R_CONFLICT!"=="Y" (set "R_CONFLICT_TXT=%L_DIAG_STATUS_PRESENT%") else (set "R_CONFLICT_TXT=%L_DIAG_STATUS_MISSING%")

rem --- IPv4/IPv6 ---
echo.
echo %L_DIAG_CONN_SECTION%
ipconfig | find /I "IPv4" >nul
if %errorlevel%==0 (set "R_IPV4=Y") else (set "R_IPV4=N")
ipconfig | find /I "IPv6" >nul
if %errorlevel%==0 (set "R_IPV6=Y") else (set "R_IPV6=N")
if "!R_IPV4!"=="Y" (set "R_IPV4_TXT=%L_DIAG_STATUS_PRESENT%") else (set "R_IPV4_TXT=%L_DIAG_STATUS_MISSING%")
if "!R_IPV6!"=="Y" (set "R_IPV6_TXT=%L_DIAG_STATUS_PRESENT%") else (set "R_IPV6_TXT=%L_DIAG_STATUS_MISSING%")
echo %L_DIAG_IPV4_LABEL% !R_IPV4_TXT!
echo %L_DIAG_IPV6_LABEL% !R_IPV6_TXT!

rem --- HTTPS/uygulama erisim testi ---
echo.
echo !L_DIAG_TEST_SECTION!
where curl >nul 2>&1
if %errorlevel%==0 (
    for %%D in (discord.com:Discord www.roblox.com:Roblox store.steampowered.com:Steam cloudflare.com:HTTPS_genel) do (
        for /f "tokens=1,2 delims=:" %%X in ("%%D") do (
            curl -s -o nul --max-time 6 "https://%%X"
            if !errorlevel!==0 (
                echo   %%Y : %L_DIAG_TEST_OK%
                set "R_%%Y=OK"
            ) else (
                echo   %%Y : %L_DIAG_TEST_FAIL%
                set "R_%%Y=FAIL"
            )
        )
    )
) else (
    echo   %L_DIAG_CURL_MISSING%
    set "R_Discord=NA"
    set "R_Roblox=NA"
    set "R_Steam=NA"
    set "R_HTTPS_genel=NA"
)

if "!R_Discord!"=="OK" set "R_Discord_TXT=%L_DIAG_TEST_OK%"
if "!R_Discord!"=="FAIL" set "R_Discord_TXT=%L_DIAG_TEST_FAIL%"
if "!R_Discord!"=="NA" set "R_Discord_TXT=%L_DIAG_TEST_UNKNOWN%"
if "!R_Roblox!"=="OK" set "R_Roblox_TXT=%L_DIAG_TEST_OK%"
if "!R_Roblox!"=="FAIL" set "R_Roblox_TXT=%L_DIAG_TEST_FAIL%"
if "!R_Roblox!"=="NA" set "R_Roblox_TXT=%L_DIAG_TEST_UNKNOWN%"
if "!R_Steam!"=="OK" set "R_Steam_TXT=%L_DIAG_TEST_OK%"
if "!R_Steam!"=="FAIL" set "R_Steam_TXT=%L_DIAG_TEST_FAIL%"
if "!R_Steam!"=="NA" set "R_Steam_TXT=%L_DIAG_TEST_UNKNOWN%"
if "!R_HTTPS_genel!"=="OK" set "R_HTTPS_TXT=%L_DIAG_TEST_OK%"
if "!R_HTTPS_genel!"=="FAIL" set "R_HTTPS_TXT=%L_DIAG_TEST_FAIL%"
if "!R_HTTPS_genel!"=="NA" set "R_HTTPS_TXT=%L_DIAG_TEST_UNKNOWN%"

rem --- DNS kontrolu: Windows'un kendi cozumleyicisinin (uygulamalarin
rem     gordugu) cevabi ile Cloudflare'in (1.1.1.1) cevabini karsilastirir.
rem     Sadece uyarir, DNS ayarina asla dokunmaz.
rem     nslookup KULLANILMAZ: nslookup yalnizca listedeki ILK DNS
rem     sunucusunu dener, o ulasilamaz bir IPv6 adresiyse hic cevap
rem     alamaz; Windows ise sonraki sunuculara gecer. Bu yuzden tek bir
rem     gizli PowerShell cagrisi (Resolve-DnsName) sonuclari gecici
rem     dosyaya yazar, burada okunur (VPN algilamasiyla ayni yontem).
rem     Dosya satirlari (hepsi 3 alan, bos alan yok):
rem       DNS|<adres>|-          adaptorun DNS listesi (sirayla)
rem       SYS|<site>|<ip ip ..>  sistem cevabi (IPv4), yoksa -
rem       CF|<site>|<ip ip ..>   Cloudflare cevabi (IPv4), yoksa -
rem     Bir sitenin TUM adresleri karsilastirilir; en az bir ortak adres
rem     varsa "ayni" sayilir (CDN farki yanlis alarm vermesin).
rem     DIKKAT: PowerShell satirinda ! ve % kullanma. ---
echo.
echo !L_DIAG_DNS_SECTION!
set "ZT_DNS_OUT=%TEMP%\zt_dns.txt"
del "%ZT_DNS_OUT%" >nul 2>&1
start "" /wait /min powershell -NoProfile -WindowStyle Hidden -Command "try { $ErrorActionPreference = 'Stop'; $out = @(); $r = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0' | Sort-Object { $_.RouteMetric + $_.InterfaceMetric } | Select-Object -First 1); if ($r.Count -gt 0) { foreach ($s in @(Get-DnsClientServerAddress -InterfaceIndex $r[0].InterfaceIndex | Sort-Object AddressFamily -Descending)) { foreach ($a in @($s.ServerAddresses)) { $out += ('DNS|' + $a + '|-') } } }; foreach ($h in @('discord.com','www.roblox.com','store.steampowered.com')) { $sys = @(); $cf = @(); try { $sys = @(Resolve-DnsName -Name $h -Type A -DnsOnly -ErrorAction Stop | Where-Object { $_.Type -eq 'A' } | ForEach-Object { $_.IPAddress }) } catch { }; try { $cf = @(Resolve-DnsName -Name $h -Type A -Server 1.1.1.1 -DnsOnly -QuickTimeout -ErrorAction Stop | Where-Object { $_.Type -eq 'A' } | ForEach-Object { $_.IPAddress }) } catch { }; $s1 = ($sys -join ' '); if ($s1 -eq '') { $s1 = '-' }; $c1 = ($cf -join ' '); if ($c1 -eq '') { $c1 = '-' }; $out += ('SYS|' + $h + '|' + $s1); $out += ('CF|' + $h + '|' + $c1) }; [System.IO.File]::WriteAllLines($env:ZT_DNS_OUT, [string[]]$out) } catch { [System.IO.File]::WriteAllText($env:ZT_DNS_OUT, 'ERR|-|-') }" >nul 2>&1

set "R_DNS_PS_OK=0"
set "R_DNSFIRST="
if exist "%ZT_DNS_OUT%" (
    set "R_DNS_PS_OK=1"
    for /f "usebackq tokens=1,2,* delims=|" %%A in ("%ZT_DNS_OUT%") do (
        if /i "%%A"=="ERR" set "R_DNS_PS_OK=0"
        if /i "%%A"=="DNS" if not defined R_DNSFIRST set "R_DNSFIRST=%%B"
        if /i "%%A"=="SYS" set "SYS_%%B=%%C"
        if /i "%%A"=="CF" set "CF_%%B=%%C"
    )
)
if defined R_DNSFIRST echo !L_DIAG_DNS_FIRST_SERVER_LABEL! !R_DNSFIRST!

rem Cloudflare'e ulasilabiliyor mu: hicbir siteden Cloudflare cevabi gelmediyse
rem (PowerShell calistiysa) karsilastirma yapilamaz.
set "R_CF_ANY=0"
for %%H in (discord.com www.roblox.com store.steampowered.com) do (
    set "TCF="
    set "TCF=!CF_%%H!"
    if defined TCF if not "!TCF!"=="-" set "R_CF_ANY=1"
)
if "!R_DNS_PS_OK!"=="1" if "!R_CF_ANY!"=="0" (
    echo !L_DIAG_DNS_UNREACHABLE!
    goto DIAG_DNS_END
)

set "R_DNS_ANY_DIFF=0"
set "R_DNS_DISCORD_DIFF=0"
set "R_SYS_ANY=0"
for %%D in (discord.com:Discord www.roblox.com:Roblox store.steampowered.com:Steam) do (
    for /f "tokens=1,2 delims=:" %%X in ("%%D") do (
        set "DNSC_SYS_ALL="
        set "DNSC_CF_ALL="
        set "DNSC_SYS_ALL=!SYS_%%X!"
        set "DNSC_CF_ALL=!CF_%%X!"
        if "!DNSC_SYS_ALL!"=="-" set "DNSC_SYS_ALL="
        if "!DNSC_CF_ALL!"=="-" set "DNSC_CF_ALL="
        set "DNSC_SYS="
        set "DNSC_CF="
        if defined DNSC_SYS_ALL for /f "tokens=1" %%I in ("!DNSC_SYS_ALL!") do set "DNSC_SYS=%%I"
        if defined DNSC_CF_ALL for /f "tokens=1" %%I in ("!DNSC_CF_ALL!") do set "DNSC_CF=%%I"
        set "DNSC_SHOW_SYS=!DNSC_SYS!"
        set "DNSC_SHOW_CF=!DNSC_CF!"
        if not defined DNSC_SYS set "DNSC_SHOW_SYS=!L_DIAG_TEST_UNKNOWN!"
        if not defined DNSC_CF set "DNSC_SHOW_CF=!L_DIAG_TEST_UNKNOWN!"
        if defined DNSC_SYS set "R_SYS_ANY=1"
        set "DNSC_VERDICT=!L_DIAG_TEST_UNKNOWN!"
        if defined DNSC_SYS if defined DNSC_CF (
            call :DIAG_DNS_OVERLAP
            if "!DNS_OVERLAP!"=="1" (
                set "DNSC_VERDICT=!L_DIAG_DNS_MATCH!"
            ) else (
                set "DNSC_VERDICT=!L_DIAG_DNS_DIFFERENT!"
                set "R_DNS_ANY_DIFF=1"
                if "%%Y"=="Discord" set "R_DNS_DISCORD_DIFF=1"
            )
        )
        echo   %%Y: !L_DIAG_DNS_SYSTEM_LABEL!=!DNSC_SHOW_SYS!  !L_DIAG_DNS_CLOUDFLARE_LABEL!=!DNSC_SHOW_CF!  [!DNSC_VERDICT!]
    )
)
echo !L_DIAG_DNS_CDN_NOTE!
echo.

rem ilk DNS sunucusu modem/yonlendirici gibi mi (ozel aralik / link-local / ULA)
set "R_DNSFIRST_IS_ROUTER=0"
if defined R_DNSFIRST (
    echo !R_DNSFIRST! | findstr /r /c:"^192\.168\." /c:"^10\." /c:"^172\.1[6-9]\." /c:"^172\.2[0-9]\." /c:"^172\.3[01]\." /c:"^[fF][eE]80" /c:"^[fF][cCdD]" >nul
    if !errorlevel!==0 set "R_DNSFIRST_IS_ROUTER=1"
)

rem Sonuc: duz ve sirali, hicbir kosulun icine gomulu degil.
rem Hicbir sitede sistem cevabi yoksa (veya PowerShell calismadiysa)
rem sonuc yazilmaz; site satirlari BILINMIYOR gosterir.
set "DNSV="
if "!R_DNS_DISCORD_DIFF!"=="1" if "!R_DNSFIRST_IS_ROUTER!"=="1" set "DNSV=!L_DIAG_DNS_VERDICT_MODEM_BAD!"
if not defined DNSV if "!R_DNS_ANY_DIFF!"=="1" if "!R_DNSFIRST_IS_ROUTER!"=="1" set "DNSV=!L_DIAG_DNS_VERDICT_MODEM_OK!"
if not defined DNSV if "!R_DNS_ANY_DIFF!"=="1" set "DNSV=!L_DIAG_DNS_VERDICT_OTHER_DIFF!"
if not defined DNSV if "!R_SYS_ANY!"=="1" set "DNSV=!L_DIAG_DNS_VERDICT_OK!"
if defined DNSV echo !DNSV!

:DIAG_DNS_END

echo.
echo ============================================================
echo.
choice /c YN /n /m "!L_DIAG_REPORT_PROMPT! "
if errorlevel 2 goto DIAG_SKIP_REPORT

if not exist "%LOGS%" mkdir "%LOGS%" >nul 2>&1
set "REPORT=%LOGS%\diagnostic-report.txt"
> "%REPORT%" echo %L_DIAG_REPORT_HEADER%
>> "%REPORT%" echo %L_DIAG_REPORT_DATE_LABEL% %date% %time%
>> "%REPORT%" echo.
>> "%REPORT%" echo %L_DIAG_REPORT_PROFILE_LABEL% !CURRENT_PROFILE!
>> "%REPORT%" echo %L_DIAG_REPORT_DNSMODE_LABEL% !R_DNSMODE!
>> "%REPORT%" echo %L_DIAG_REPORT_ADMIN_LABEL% !R_ADMIN_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_WINWS_LABEL% !R_RUN_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_SVC_LABEL% !R_SVC_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_IPV4_LABEL% !R_IPV4_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_IPV6_LABEL% !R_IPV6_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_CONFLICT_LABEL% !R_CONFLICT_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_DISCORD_LABEL% !R_Discord_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_ROBLOX_LABEL% !R_Roblox_TXT!
>> "%REPORT%" echo %L_DIAG_REPORT_STEAM_LABEL% !R_Steam_TXT!
>> "%REPORT%" echo !L_DIAG_REPORT_HTTPS_LABEL! !R_HTTPS_TXT!
>> "%REPORT%" echo.
>> "%REPORT%" echo %L_DIAG_REPORT_NOTE_1%
>> "%REPORT%" echo %L_DIAG_REPORT_NOTE_2%
>> "%REPORT%" echo !L_DIAG_REPORT_NOTE_3!
>> "%REPORT%" echo %L_DIAG_REPORT_NOTE_4%
echo %L_DIAG_REPORT_DONE% %REPORT%

:DIAG_SKIP_REPORT
exit /b 0

rem ============================================================
rem  DIAG_DNS_OVERLAP
rem  DNSC_SYS_ALL ve DNSC_CF_ALL listelerinde ortak en az bir adres
rem  varsa DNS_OVERLAP=1
rem ============================================================
:DIAG_DNS_OVERLAP
set "DNS_OVERLAP=0"
for %%A in (!DNSC_SYS_ALL!) do (
    for %%B in (!DNSC_CF_ALL!) do (
        if /i "%%A"=="%%B" set "DNS_OVERLAP=1"
    )
)
exit /b
