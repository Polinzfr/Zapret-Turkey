@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Zapret Turkey
chcp 65001 >nul

rem ===================== ANSI renk kodlari =====================
for /F %%a in ('echo prompt $E^| cmd') do set "ESC=%%a"
set "C_RESET=%ESC%[0m"
set "C_GREEN=%ESC%[92m"
set "C_RED=%ESC%[91m"
set "C_YELLOW=%ESC%[93m"
set "C_CYAN=%ESC%[96m"
set "C_GRAY=%ESC%[90m"

rem ===================== yollar (her zaman %~dp0 uzerinden) =====================
set "ROOT=%~dp0"
set "ENGINE_DIR=%ROOT%engine"
set "PROFILE_DIR=%ROOT%profiles"
set "CONFIG_FILE=%ROOT%config\settings.conf"
set "LOG_DIR=%ROOT%logs"
set "SVCNAME=ZapretTurkey"

rem ===================== yonetici kontrolu =====================
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo %C_YELLOW%Yonetici yetkisi gerekiyor.%C_RESET%
    choice /c YN /n /m "Yeniden yonetici olarak baslatilsin mi? [Y/N]: "
    if errorlevel 2 (
        echo.
        echo Yonetici yetkisi olmadan baslatma/durdurma ve hizmet islemleri calismaz.
        pause
        exit /b 1
    ) else (
        echo Set UAC = CreateObject^("Shell.Application"^) > "%TEMP%\zt_admin.vbs"
        echo UAC.ShellExecute "%~f0", "", "", "runas", 1 >> "%TEMP%\zt_admin.vbs"
        "%TEMP%\zt_admin.vbs"
        del "%TEMP%\zt_admin.vbs" >nul 2>&1
        exit /b
    )
)

rem ===================== dosya kontrolleri =====================
if not exist "%ENGINE_DIR%\winws.exe" (
    echo %C_RED%[HATA] engine\winws.exe bulunamadi. Beklenen yol:%C_RESET%
    echo   %ENGINE_DIR%\winws.exe
    pause
    exit /b 1
)
if not exist "%ENGINE_DIR%\WinDivert64.sys" (
    echo %C_RED%[HATA] engine\WinDivert64.sys bulunamadi. Beklenen yol:%C_RESET%
    echo   %ENGINE_DIR%\WinDivert64.sys
    pause
    exit /b 1
)
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1
if not exist "%CONFIG_FILE%" (
    > "%CONFIG_FILE%" echo CURRENT_PROFILE=stable
    >> "%CONFIG_FILE%" echo DNS_MODE=system
    >> "%CONFIG_FILE%" echo DEBUG=0
)

goto MAIN_MENU

rem ============================================================
rem  ANA MENU
rem ============================================================
:MAIN_MENU
cls
call :LOAD_SETTINGS
call :GET_DISPLAY_NAME "!CURRENT_PROFILE!" PROFNAME
call :CHECK_RUNNING RUNSTATE
call :CHECK_SERVICE SVCSTATE

echo %C_CYAN%============================================================%C_RESET%
echo %C_CYAN%   ZAPRET TURKEY - Turkiye DPI Bypass Utility%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
if "!RUNSTATE!"=="AKTIF" (
    echo   Durum        : %C_GREEN%AKTIF%C_RESET%
) else (
    echo   Durum        : %C_RED%DURDU%C_RESET%
)
echo   Profil       : !CURRENT_PROFILE! (!PROFNAME!)
echo   DNS modu     : !DNS_MODE!
echo   Hizmet       : !SVCSTATE!
echo %C_CYAN%------------------------------------------------------------%C_RESET%
echo   %C_CYAN%[1]%C_RESET%  Baslat
echo   %C_CYAN%[2]%C_RESET%  Durdur
echo   %C_CYAN%[3]%C_RESET%  Profil Degistir
echo   %C_CYAN%[4]%C_RESET%  Otomatik Test
echo   %C_CYAN%[5]%C_RESET%  Hizmet Ayarlari
echo   %C_CYAN%[6]%C_RESET%  Tanilama
echo   %C_CYAN%[7]%C_RESET%  Ayarlar
echo   %C_CYAN%[8]%C_RESET%  Gunlukler
echo   %C_CYAN%[9]%C_RESET%  Debug Mode
echo   %C_CYAN%[0]%C_RESET%  Cikis
echo %C_CYAN%------------------------------------------------------------%C_RESET%
echo.
set /p "CH=Secim: "

if "%CH%"=="1" call :START_ENGINE & goto MAIN_MENU
if "%CH%"=="2" call :STOP_ENGINE & goto MAIN_MENU
if "%CH%"=="3" call :CHANGE_PROFILE & goto MAIN_MENU
if "%CH%"=="4" call :AUTO_TEST & goto MAIN_MENU
if "%CH%"=="5" call :SERVICE_MENU & goto MAIN_MENU
if "%CH%"=="6" call "%ROOT%scripts\diagnostics.bat" & pause & goto MAIN_MENU
if "%CH%"=="7" call :SETTINGS_MENU & goto MAIN_MENU
if "%CH%"=="8" call :LOGS_MENU & goto MAIN_MENU
if "%CH%"=="9" call :DEBUG_PANEL & goto MAIN_MENU
if "%CH%"=="0" goto END
goto MAIN_MENU

rem ============================================================
rem  CIKIS
rem ============================================================
:END
cls
sc query "%SVCNAME%" 2>nul | find "RUNNING" >nul
if %errorlevel%==0 (
    echo Zapret Turkey hizmeti arka planda calismaya devam edecek.
) else (
    tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
    if %errorlevel%==0 (
        choice /c YN /n /m "winws hala calisiyor. Kapatilsin mi? [Y/N]: "
        if not errorlevel 2 (
            taskkill /F /IM winws.exe >nul 2>&1
            echo winws kapatildi.
        )
    )
)
echo DNS ayarlariniza dokunulmadi.
echo Zapret Turkey kapatiliyor...
timeout /t 1 >nul
exit /b 0

rem ============================================================
rem  YARDIMCI: ayarlari oku
rem ============================================================
:LOAD_SETTINGS
set "CURRENT_PROFILE=stable"
set "DNS_MODE=system"
set "DEBUG=0"
for /f "usebackq tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
    set "_k=%%A"
    if not "!_k:~0,1!"=="#" if not "%%A"=="" set "%%A=%%B"
)
exit /b

rem ============================================================
rem  YARDIMCI: tek ayari guncelle (config\settings.conf)
rem  ONEMLI: bu ayari SABIT 3 satirla YENIDEN yazar - dinamik
rem  satir eslestirme / FOR-icinde-FOR kullanilmaz. Onceki surumdeki
rem  ic ice FOR/IF yapisi bazi cmd.exe kurulumlarinda "SET_SETTING"
rem  label'inin bulunamamasina yol aciyordu; bu sade yapi bunu ortadan
rem  kaldirir.
rem ============================================================
:SET_SETTING
call :LOAD_SETTINGS
if /I "%~1"=="CURRENT_PROFILE" set "CURRENT_PROFILE=%~2"
if /I "%~1"=="DNS_MODE" set "DNS_MODE=%~2"
if /I "%~1"=="DEBUG" set "DEBUG=%~2"
> "%CONFIG_FILE%" echo CURRENT_PROFILE=%CURRENT_PROFILE%
>> "%CONFIG_FILE%" echo DNS_MODE=%DNS_MODE%
>> "%CONFIG_FILE%" echo DEBUG=%DEBUG%
exit /b

rem ============================================================
rem  YARDIMCI: profil goruntu adi - SABIT ES LESME TABLOSU
rem  (dosyadan okuma yok; sadece bu 3 ID desteklenir)
rem ============================================================
:GET_DISPLAY_NAME
set "gdn_id=%~1"
set "gdn_out=%~2"
if /I "%gdn_id%"=="stable" (
    set "%gdn_out%=Turkiye Stable (HostFakeSplit)"
) else if /I "%gdn_id%"=="compatibility" (
    set "%gdn_out%=Uyumluluk (Fake)"
) else if /I "%gdn_id%"=="strong" (
    set "%gdn_out%=Guclu (MultiSplit)"
) else (
    set "%gdn_out%=Bilinmeyen profil (%gdn_id%)"
)
exit /b

rem ============================================================
rem  YARDIMCI: winws calisiyor mu
rem ============================================================
:CHECK_RUNNING
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (set "%~1=AKTIF") else (set "%~1=DURDU")
exit /b

rem ============================================================
rem  YARDIMCI: hizmet kurulu mu
rem ============================================================
:CHECK_SERVICE
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (set "%~1=KURULU") else (set "%~1=KURULU DEGIL")
exit /b

rem ============================================================
rem  CEKIRDEK: profili baslat ve GERCEKTEN calisip calismadigini
rem  dogrula. Hem manuel Baslat hem Otomatik Test bunu kullanir.
rem  Sonuc degiskenleri (cagiran tarafindan okunur):
rem    CORE_OK          0 veya 1
rem    CORE_REASON      OK / PROFILE_NOT_FOUND / PROFILE_PARSE_FAILED /
rem                     ENGINE_MISSING / WINDIVERT_MISSING / NOT_ADMIN /
rem                     ENGINE_EXITED / UNKNOWN_STATE
rem    CORE_CONFPATH    kullanilan profil dosyasinin tam yolu
rem    CORE_CMDLINE     calistirilan gercek komut satiri
rem    CORE_EXITCODE    (yalnizca ENGINE_EXITED durumunda) cikis kodu
rem    CORE_STDERR_TAIL (yalnizca ENGINE_EXITED durumunda) son stderr satiri
rem  DIKKAT: bu label FOR dongusu govdesi icinden CAGRILMAMALI -
rem  cmd.exe bazi surumlerde "call :label" dogru calismasi icin
rem  cagrinin ust seviyede (parantezli blok icinde degil) olmasini ister.
rem ============================================================
:ENGINE_START_CORE
rem %1 = profil ID.  %2 = VISIBLE (varsayilan) veya HIDDEN.
rem   VISIBLE : winws.exe kendi ayri, kucultulmus penceresinde
rem             calisir (Baslat menusu icin - kullanicinin gormek
rem             ve surdurmek istedigi kalici islem).
rem   HIDDEN  : winws.exe HICBIR PENCERE ACMADAN calisir (Otomatik
rem             Test icin - saniyeler icinde baslatilip durdurulan
rem             gecici testler; tekrar tekrar pencere acilip
rem             kapanmasi rahatsiz edici oldugu icin VBS "gizli
rem             calistirma" hilesi kullanilir - asagida).
set "CORE_PROFILE=%~1"
set "CORE_MODE=%~2"
if "%CORE_MODE%"=="" set "CORE_MODE=VISIBLE"
set "CORE_OK=0"
set "CORE_REASON="
set "CORE_EXITCODE="
set "CORE_STDERR_TAIL="
set "CORE_CMDLINE="
set "CORE_CONFPATH=%PROFILE_DIR%\%CORE_PROFILE%.conf"

if not exist "%CORE_CONFPATH%" (
    set "CORE_REASON=PROFILE_NOT_FOUND"
    exit /b 1
)

set "CORE_ARGS="
set "CORE_PORT=443"
for /f "usebackq tokens=1,* delims==" %%A in ("%CORE_CONFPATH%") do (
    if "%%A"=="ARGS" set "CORE_ARGS=%%B"
    if "%%A"=="PORT_TCP" set "CORE_PORT=%%B"
)
if not defined CORE_ARGS (
    set "CORE_REASON=PROFILE_PARSE_FAILED"
    exit /b 1
)

rem Onceki calisma zamani eklemeleri, profil dosyalarindaki ARGS
rem satirini DEGISTIRMEZ - sadece bu oturumun komut satirina EKLENIR.
rem profiles\*.conf dosyalari degismeden kalir.

rem Hedef liste (--hostlist): desync SADECE bu listedeki adreslere
rem uygulanir - listede olmayan HER SEY (normal siteler) hic
rem dokunulmadan gecer. Bu, "normal siteler bozuluyor" sorununu
rem kaynaginda cozer (onceden TUM TCP/443 trafigine uygulaniyordu).
set "CORE_TARGET_FILE=%PROFILE_DIR%\target-hosts.txt"
if exist "%CORE_TARGET_FILE%" (
    set "CORE_ARGS=%CORE_ARGS% --hostlist="%CORE_TARGET_FILE%""
)

rem Bilinen uyumsuzluklar icin haric tutma listesi (WhatsApp gibi -
rem hedef listede olmasa bile ekstra guvenlik).
set "CORE_EXCLUDE_FILE=%PROFILE_DIR%\exclude-hosts.txt"
if exist "%CORE_EXCLUDE_FILE%" (
    set "CORE_ARGS=%CORE_ARGS% --hostlist-exclude="%CORE_EXCLUDE_FILE%""
)

if not exist "%ENGINE_DIR%\winws.exe" (
    set "CORE_REASON=ENGINE_MISSING"
    exit /b 1
)
if not exist "%ENGINE_DIR%\WinDivert.dll" (
    set "CORE_REASON=WINDIVERT_MISSING"
    exit /b 1
)
if not exist "%ENGINE_DIR%\WinDivert64.sys" (
    set "CORE_REASON=WINDIVERT_MISSING"
    exit /b 1
)

net session >nul 2>&1
if not %errorlevel%==0 (
    set "CORE_REASON=NOT_ADMIN"
    exit /b 1
)

rem ayni anda baska bir kopya calismasin
taskkill /F /IM winws.exe >nul 2>&1
timeout /t 1 >nul

if exist "%LOG_DIR%\engine_stderr.log" del "%LOG_DIR%\engine_stderr.log" >nul 2>&1
if exist "%LOG_DIR%\engine_stdout.log" del "%LOG_DIR%\engine_stdout.log" >nul 2>&1

set "CORE_CMDLINE="%ENGINE_DIR%\winws.exe" --wf-tcp=%CORE_PORT% %CORE_ARGS%"

if /I "%CORE_MODE%"=="HIDDEN" (
    rem --- tamamen gizli calistirma (Otomatik Test icin) ---
    rem Hicbir pencere acilmaz/gorunmez. "start /min" bile teknik
    rem olarak bir pencere YARATIR (sadece kucultulmus) ve olusma/
    rem yok olma aninda kisa bir gorsel goruntu birakabilir. Bu VBS
    rem teknigi hicbir pencere yaratmadigi icin o goruntu de olmaz.
    > "%LOG_DIR%\_hidden_engine.bat" echo @echo off
    >> "%LOG_DIR%\_hidden_engine.bat" echo %CORE_CMDLINE% ^> "%LOG_DIR%\engine_stdout.log" 2^> "%LOG_DIR%\engine_stderr.log"
    > "%LOG_DIR%\_hidden_launcher.vbs" echo Set WshShell = CreateObject^("WScript.Shell"^)
    >> "%LOG_DIR%\_hidden_launcher.vbs" echo WshShell.Run Chr^(34^) ^& "%LOG_DIR%\_hidden_engine.bat" ^& Chr^(34^), 0, False
    wscript.exe //nologo "%LOG_DIR%\_hidden_launcher.vbs"
) else (
    rem --- ayri, gorunur pencere (Baslat menusu icin) ---
    start "ZapretTurkey" /min "%ENGINE_DIR%\winws.exe" --wf-tcp=%CORE_PORT% %CORE_ARGS% > "%LOG_DIR%\engine_stdout.log" 2> "%LOG_DIR%\engine_stderr.log"
)

set "CORE_POLL=0"
:CORE_POLL_LOOP
timeout /t 1 >nul
set /a CORE_POLL+=1
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 goto CORE_RUNNING
if %CORE_POLL% LSS 4 goto CORE_POLL_LOOP

set "CORE_REASON=ENGINE_EXITED"
if exist "%LOG_DIR%\engine_stderr.log" (
    for /f "usebackq delims=" %%L in ("%LOG_DIR%\engine_stderr.log") do set "CORE_STDERR_TAIL=%%L"
)
exit /b 1

:CORE_RUNNING
set "CORE_OK=1"
set "CORE_REASON=OK"
exit /b 0

rem ============================================================
rem  BASLAT (menuden - detayli hata gosterir, pencere kapanmaz)
rem ============================================================
:START_ENGINE
call :LOAD_SETTINGS
call :ENGINE_START_CORE "!CURRENT_PROFILE!"

if "!CORE_OK!"=="1" (
    echo %C_GREEN%Profil baslatildi.%C_RESET%
    echo Komut satiri: !CORE_CMDLINE!
    echo Discord ve Roblox gibi uygulamalari tamamen kapatip yeniden acarak test edin.
    >> "%LOG_DIR%\app.log" echo [%date% %time%] START OK profile=!CURRENT_PROFILE!
    pause
    exit /b
)

echo %C_RED%START FAILED%C_RESET%
echo Profile: !CURRENT_PROFILE!
echo Reason : !CORE_REASON!
if "!CORE_REASON!"=="PROFILE_NOT_FOUND" (
    echo Path   : !CORE_CONFPATH!
)
if "!CORE_REASON!"=="PROFILE_PARSE_FAILED" (
    echo Path   : !CORE_CONFPATH!
    echo Profil dosyasinda "ARGS=..." satiri bulunamadi veya bos.
)
if "!CORE_REASON!"=="ENGINE_MISSING" (
    echo Beklenen yol: !ENGINE_DIR!\winws.exe
)
if "!CORE_REASON!"=="WINDIVERT_MISSING" (
    echo engine\ klasorunde WinDivert.dll veya WinDivert64.sys eksik.
)
if "!CORE_REASON!"=="NOT_ADMIN" (
    echo Program yonetici yetkisiyle yeniden baslatilmali.
)
if "!CORE_REASON!"=="ENGINE_EXITED" (
    echo Komut satiri: !CORE_CMDLINE!
    echo stderr      : !CORE_STDERR_TAIL!
    echo Tam stderr icin: !LOG_DIR!\engine_stderr.log
)
if "!CORE_REASON!"=="UNKNOWN_STATE" (
    echo winws.exe ne calisir durumda ne de bir cikis kodu birakti.
    echo Tanilama menusunu ^(secenek 6^) kullanin.
)
>> "%LOG_DIR%\app.log" echo [%date% %time%] START FAILED profile=!CURRENT_PROFILE! reason=!CORE_REASON!
echo.
pause
exit /b

rem ============================================================
rem  DURDUR
rem ============================================================
:STOP_ENGINE
taskkill /F /IM winws.exe >nul 2>&1
if %errorlevel%==0 (
    echo %C_GREEN%winws durduruldu.%C_RESET%
    >> "%LOG_DIR%\app.log" echo [%date% %time%] STOP
) else (
    echo %C_GRAY%winws zaten calismiyordu.%C_RESET%
)
pause
exit /b

rem ============================================================
rem  PROFIL DEGISTIR  (sadece stable / compatibility / strong)
rem ============================================================
:CHANGE_PROFILE
cls
call :GET_DISPLAY_NAME stable N1
call :GET_DISPLAY_NAME compatibility N2
call :GET_DISPLAY_NAME strong N3
echo Profil secin:
echo.
echo   [1] stable        - !N1!
echo   [2] compatibility - !N2!
echo   [3] strong        - !N3!
echo   [0] Iptal
echo.
set /p "PC=Secim: "
set "NEWP="
if "%PC%"=="1" set "NEWP=stable"
if "%PC%"=="2" set "NEWP=compatibility"
if "%PC%"=="3" set "NEWP=strong"
if not defined NEWP exit /b

call :SET_SETTING CURRENT_PROFILE !NEWP!
echo %C_GREEN%Profil degistirildi: !NEWP!%C_RESET%

tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (
    choice /c YN /n /m "winws su an calisiyor. Yeni profille yeniden baslatilsin mi? [Y/N]: "
    if not errorlevel 2 call :START_ENGINE
)

sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (
    echo %C_YELLOW%Not: Hizmet olarak kuruluysa, yeni profilin gecerli olmasi icin%C_RESET%
    echo %C_YELLOW%Hizmet Ayarlari - Hizmeti Kur secenegini tekrar calistirin.%C_RESET%
)
pause
exit /b

rem ============================================================
rem  OTOMATIK TEST
rem  ONEMLI: profiller bir FOR dongusu icinde CALL ile degil,
rem  ust seviyede (dongusuz) 3 ayri CALL ile sirayla test edilir.
rem  (Onceki surumde FOR govdesi icinde "call :label" kullanimi
rem  cmd.exe'de "cannot find batch label" hatasina yol aciyordu.)
rem ============================================================
:AUTO_TEST
cls
echo %C_CYAN%Otomatik profil testi%C_RESET%
echo Bu islem sirasinda winws birkac kez yeniden baslatilacak.
echo Test kapsami: yalnizca temel HTTPS/TCP baglanti testi (Discord, Roblox,
echo Steam alan adlarina baglanti kurulabiliyor mu). Uygulama ici davranis
echo ^(mesaj, CDN, WebSocket vb.^) bu testte KONTROL EDILMEZ.
echo.
where curl >nul 2>&1
if not %errorlevel%==0 (
    echo %C_RED%[HATA] curl.exe bulunamadi. Windows 10 1803+ / Windows 11 gerekli.%C_RESET%
    pause
    exit /b
)
choice /c YN /n /m "Devam edilsin mi? [Y/N]: "
if errorlevel 2 exit /b

set "RESULT_stable=SKIP"
set "RESULT_compatibility=SKIP"
set "RESULT_strong=SKIP"

call :RUN_AUTOTEST_ONE stable
call :RUN_AUTOTEST_ONE compatibility
call :RUN_AUTOTEST_ONE strong

taskkill /F /IM winws.exe >nul 2>&1

echo.
echo %C_CYAN%================= SONUC =================%C_RESET%
echo   STABLE        = !RESULT_stable!
echo   COMPATIBILITY = !RESULT_compatibility!
echo   STRONG        = !RESULT_strong!
echo %C_CYAN%==========================================%C_RESET%

set "WINNER="
if "!RESULT_stable!"=="PASS" set "WINNER=stable"
if not defined WINNER if "!RESULT_compatibility!"=="PASS" set "WINNER=compatibility"
if not defined WINNER if "!RESULT_strong!"=="PASS" set "WINNER=strong"

if defined WINNER call :GET_DISPLAY_NAME !WINNER! WN

if defined WINNER (
    echo.
    echo %C_GREEN%Onerilen profil: !WINNER! ^(!WN!^)%C_RESET%
) else (
    echo.
    echo %C_RED%Hicbir profil temel baglanti testini gecemedi.%C_RESET%
    echo Tanilama menusunu ^(secenek 6^) kullanarak ag/WinDivert durumunu kontrol edin.
)

set "SAVE_CH=0"
if defined WINNER (
    choice /c YN /n /m "Bu profil varsayilan olarak kaydedilsin mi? [Y/N]: "
    set "SAVE_CH=!errorlevel!"
)
if "!SAVE_CH!"=="1" call :SET_SETTING CURRENT_PROFILE !WINNER!
if "!SAVE_CH!"=="1" echo Kaydedildi.

>> "%LOG_DIR%\app.log" echo [%date% %time%] AUTO_TEST stable=!RESULT_stable! compatibility=!RESULT_compatibility! strong=!RESULT_strong!
pause
exit /b

rem ============================================================
rem  Otomatik testte TEK BIR profili calistir - ust seviyeden
rem  (yani bir FOR dongusu govdesi icinden DEGIL) cagrilir.
rem  %1 = profil ID (stable|compatibility|strong)
rem ============================================================
:RUN_AUTOTEST_ONE
set "RA_ID=%~1"
call :GET_DISPLAY_NAME %RA_ID% RA_NAME
echo.
echo %C_CYAN%--- Test ediliyor: %RA_ID% (%RA_NAME%) ---%C_RESET%

call :SET_SETTING CURRENT_PROFILE %RA_ID%
call :ENGINE_START_CORE %RA_ID% HIDDEN

if not "!CORE_OK!"=="1" (
    echo %C_RED%Baslatilamadi. Neden: !CORE_REASON!%C_RESET%
    set "RESULT_%RA_ID%=FAIL"
    exit /b
)

echo winws calisiyor, baglanti testi yapiliyor...
call :TEST_ENDPOINTS RA_TESTRESULT
taskkill /F /IM winws.exe >nul 2>&1

if "!RA_TESTRESULT!"=="OK" (
    echo %C_GREEN%PASS%C_RESET%
    set "RESULT_%RA_ID%=PASS"
) else (
    echo %C_RED%FAIL%C_RESET% ^(baglanti testi basarisiz^)
    set "RESULT_%RA_ID%=FAIL"
)
exit /b

rem ============================================================
rem  YARDIMCI: uc test adresine baglanti kontrolu
rem ============================================================
:TEST_ENDPOINTS
set "endvar=%~1"
set "OKCOUNT=0"
set "TOTAL=0"
for %%D in (https://discord.com https://www.roblox.com https://store.steampowered.com) do (
    set /a TOTAL+=1
    curl -s -o nul --max-time 6 "%%D"
    if !errorlevel!==0 set /a OKCOUNT+=1
)
if !OKCOUNT!==!TOTAL! (set "%endvar%=OK") else (set "%endvar%=FAIL")
exit /b

rem ============================================================
rem  HIZMET AYARLARI
rem ============================================================
:SERVICE_MENU
cls
call :CHECK_SERVICE SVCSTATE
echo %C_CYAN%============================================================%C_RESET%
echo   HIZMET AYARLARI
echo %C_CYAN%============================================================%C_RESET%
echo   Hizmet durumu: !SVCSTATE!
echo.
echo   [1] Hizmeti Kur          (mevcut profille, otomatik baslatma)
echo   [2] Hizmeti Kaldir
echo   [3] Hizmeti Baslat
echo   [4] Hizmeti Durdur
echo   [0] Geri
echo.
set /p "SVC=Secim: "
if "%SVC%"=="1" call "%ROOT%scripts\install-service.bat"
if "%SVC%"=="2" call "%ROOT%scripts\uninstall-service.bat"
if "%SVC%"=="3" (sc start "%SVCNAME%" & pause)
if "%SVC%"=="4" (sc stop "%SVCNAME%" & pause)
exit /b

rem ============================================================
rem  AYARLAR (DNS, Debug)
rem ============================================================
:SETTINGS_MENU
cls
call :LOAD_SETTINGS
echo %C_CYAN%============================================================%C_RESET%
echo   AYARLAR
echo %C_CYAN%============================================================%C_RESET%
echo   DNS modu   : !DNS_MODE!   (varsayilan: system - hicbir sey degistirilmez)
echo   Debug modu : !DEBUG!
echo.
echo   [1] DNS'e dokunma (varsayilana don / etiketi guncelle)
echo   [2] Cloudflare DNS ayarla (1.1.1.1 / 1.0.0.1) - agi degistirir
echo   [3] DNS'i otomatige (DHCP) geri al
echo   [4] Debug etiketini Ac/Kapat
echo   [0] Geri
echo.
set /p "SS=Secim: "
if "%SS%"=="1" (
    call :SET_SETTING DNS_MODE system
    echo Etiket guncellendi. Bu secenek sistem ayarina dokunmaz.
)
if "%SS%"=="2" call :DNS_SET_CLOUDFLARE
if "%SS%"=="3" call :DNS_RESET_DHCP
if "%SS%"=="4" call :TOGGLE_DEBUG
pause
exit /b

:DNS_SET_CLOUDFLARE
echo.
echo %C_YELLOW%UYARI: Bu islem Windows agindaki DNS sunucu ayarini degistirir.%C_RESET%
echo Bu, Zapret Turkey'nin varsayilan davranisi DEGILDIR; yalnizca sizin
echo bu secimi yapmaniz halinde uygulanir. Adaptor listesi asagida:
echo.
netsh interface show interface
echo.
set /p "ADPNAME=Adaptorun tam adini yazin (ornek: Ethernet, Wi-Fi): "
if "!ADPNAME!"=="" exit /b
choice /c YN /n /m "'!ADPNAME!' adaptorune Cloudflare DNS atansin mi? [Y/N]: "
if errorlevel 2 exit /b
netsh interface ip set dns name="!ADPNAME!" static 1.1.1.1 primary
netsh interface ip add dns name="!ADPNAME!" 1.0.0.1 index=2
call :SET_SETTING DNS_MODE cloudflare
echo %C_GREEN%DNS ayarlandi. Geri almak icin Ayarlar - [3] secenegini kullanin.%C_RESET%
>> "%LOG_DIR%\app.log" echo [%date% %time%] DNS SET cloudflare adapter="!ADPNAME!"
exit /b

:DNS_RESET_DHCP
echo.
netsh interface show interface
echo.
set /p "ADPNAME=DHCP'ye dondurulecek adaptorun tam adini yazin: "
if "!ADPNAME!"=="" exit /b
netsh interface ip set dns name="!ADPNAME!" dhcp
call :SET_SETTING DNS_MODE system
echo %C_GREEN%DNS otomatige (DHCP) dondu.%C_RESET%
>> "%LOG_DIR%\app.log" echo [%date% %time%] DNS RESET dhcp adapter="!ADPNAME!"
exit /b

:TOGGLE_DEBUG
call :LOAD_SETTINGS
if "!DEBUG!"=="1" (
    call :SET_SETTING DEBUG 0
    echo Debug etiketi kapatildi.
) else (
    call :SET_SETTING DEBUG 1
    echo Debug etiketi acildi.
)
exit /b

rem ============================================================
rem  GUNLUKLER
rem ============================================================
:LOGS_MENU
cls
echo %C_CYAN%============================================================%C_RESET%
echo   GUNLUKLER
echo %C_CYAN%============================================================%C_RESET%
echo   [1] Son loglari goster (app.log)
echo   [2] Log klasorunu ac
echo   [3] Son hatalari goster
echo   [4] Son engine stderr'i goster
echo   [0] Geri
echo.
set /p "LG=Secim: "
if "%LG%"=="1" (
    if exist "%LOG_DIR%\app.log" (type "%LOG_DIR%\app.log") else (echo Henuz log yok.)
    pause
)
if "%LG%"=="2" start "" explorer "%LOG_DIR%"
if "%LG%"=="3" (
    if exist "%LOG_DIR%\app.log" (
        findstr /I "HATA ERROR FAILED" "%LOG_DIR%\app.log"
    ) else (
        echo Henuz log yok.
    )
    pause
)
if "%LG%"=="4" (
    if exist "%LOG_DIR%\engine_stderr.log" (type "%LOG_DIR%\engine_stderr.log") else (echo Henuz engine stderr kaydi yok.)
    pause
)
exit /b

rem ============================================================
rem  DEBUG MODE - anlik durum paneli
rem ============================================================
:DEBUG_PANEL
cls
call :LOAD_SETTINGS
echo %C_CYAN%============================================================%C_RESET%
echo   DEBUG MODE - Anlik Durum
echo %C_CYAN%============================================================%C_RESET%
echo ROOT dizini      : %ROOT%
echo ENGINE_DIR       : %ENGINE_DIR%
echo PROFILE_DIR      : %PROFILE_DIR%
echo LOG_DIR          : %LOG_DIR%
echo.
echo Secili profil ID : !CURRENT_PROFILE!
call :GET_DISPLAY_NAME !CURRENT_PROFILE! DBG_NAME
echo Profil adi       : !DBG_NAME!
set "DBG_CONF=%PROFILE_DIR%\!CURRENT_PROFILE!.conf"
echo Profil dosyasi   : !DBG_CONF!
if exist "!DBG_CONF!" (echo   -^> dosya VAR) else (echo   -^> dosya YOK)

set "DBG_ARGS="
set "DBG_PORT=443"
if exist "!DBG_CONF!" (
    for /f "usebackq tokens=1,* delims==" %%A in ("!DBG_CONF!") do (
        if "%%A"=="ARGS" set "DBG_ARGS=%%B"
        if "%%A"=="PORT_TCP" set "DBG_PORT=%%B"
    )
)
echo Parse edilen PORT: !DBG_PORT!
echo Parse edilen ARGS: !DBG_ARGS!
echo.
net session >nul 2>&1
if %errorlevel%==0 (echo Yonetici yetkisi : EVET) else (echo Yonetici yetkisi : HAYIR)
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (echo winws durumu     : CALISIYOR) else (echo winws durumu     : CALISMIYOR)
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (echo Hizmet durumu    : KURULU) else (echo Hizmet durumu    : KURULU DEGIL)
echo.
echo --- Bu oturumdaki son ENGINE_START_CORE cagrisi ---
if defined CORE_CMDLINE (
    echo Komut satiri : !CORE_CMDLINE!
    echo Sonuc        : !CORE_REASON!
    if defined CORE_EXITCODE echo Exit code    : !CORE_EXITCODE!
    if defined CORE_STDERR_TAIL echo stderr       : !CORE_STDERR_TAIL!
) else (
    echo Bu oturumda henuz Baslat / Otomatik Test calistirilmadi.
)
echo.
echo Log dosyalari: %LOG_DIR%
echo %C_CYAN%============================================================%C_RESET%
pause
exit /b
