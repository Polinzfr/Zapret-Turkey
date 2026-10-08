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
set "ASTASK=ZapretTurkey Autostart"
set "WDTASK=ZapretTurkey Watchdog"
set "WANT_FILE=%ROOT%config\engine.want"
set "WDFAILS_FILE=%ROOT%config\watchdog.fails"
set "VPNTASK_POLL=ZapretTurkey VPN Poll"
set "VPNTASK_EVT=ZapretTurkey VPN Event"
set "VPNENABLED_FILE=%ROOT%config\vpn.enabled"
set "VPNPAUSED_FILE=%ROOT%config\vpn.paused"
set "VPNSTATE_FILE=%ROOT%config\vpn.state"
set "VPNLOCK_DIR=%ROOT%config\vpn.lock"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

rem ===================== /autostart modu (zamanlanmis gorev) =====================
rem Oturum acilisinda gizli calisan gorev bu parametreyle cagirir
rem (bkz. :AUTOSTART_ENABLE). Dil sorusu / UAC istemi / menu YOK: gorunmez
rem bir ortamda bunlar sonsuza kadar takilirdi. Bu yuzden dil yuklemeden
rem ONCE dallanir.
if /I "%~1"=="/autostart" goto AUTOSTART_RUN
rem /watchdog: ayni mantik (bkz. :WATCHDOG_RUN)
if /I "%~1"=="/watchdog" goto WATCHDOG_RUN
rem /vpncheck: VPN gecis denetcisi (bkz. :VPNCHECK_RUN)
if /I "%~1"=="/vpncheck" goto VPNCHECK_RUN

rem ===================== dil yukleme =====================
rem L_* degiskenlerini yukler; settings.conf'ta LANG= yoksa (ilk
rem calistirma) burada kullaniciya dil sorulur ve kaydedilir. Bu
rem yuzden admin yukseltme ve dosya kontrollerinden ONCE cagrilir -
rem hem o mesajlar da cevrilsin hem de admin olarak yeniden
rem baslatildiginda dil tekrar sorulmasin (zaten kaydedilmis olur).
call "%ROOT%scripts\lang-load.bat"

rem ===================== yonetici kontrolu =====================
net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo %C_YELLOW%%L_ADMIN_NEEDED%%C_RESET%
    choice /c YN /n /m "%L_ADMIN_PROMPT% "
    if errorlevel 2 (
        echo.
        echo %L_ADMIN_DENIED_1%
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
    echo %C_RED%%L_ERR_ENGINE_NOT_FOUND%%C_RESET%
    echo   %ENGINE_DIR%\winws.exe
    pause
    exit /b 1
)
if not exist "%ENGINE_DIR%\WinDivert64.sys" (
    echo %C_RED%%L_ERR_WINDIVERT_NOT_FOUND%%C_RESET%
    echo   %ENGINE_DIR%\WinDivert64.sys
    pause
    exit /b 1
)
rem NOT: config\settings.conf varsayilan olusturma islemi artik
rem scripts\lang-load.bat:SAVE_LANG_SETTING icinde yapiliyor (LANG=
rem satirini da ayni anda yazmasi gerektigi icin). Burada ayrica
rem olusturulmuyor - cakisma olmasin diye.

goto MAIN_MENU

rem ============================================================
rem  AUTOSTART_RUN - oturum acilisinda zamanlanmis gorev tarafindan
rem  (config\autostart.vbs uzerinden, gizli pencerede) cagrilir.
rem  Ayarlardaki profille winws'yi GIZLI baslatir, sonucu
rem  logs\app.log'a yazar. Yonetici degilse sormadan cikar.
rem  Windows servisi kuruluysa HICBIR SEY yapmaz: ENGINE_START_CORE
rem  baslarken calisan tum winws'leri oldurdugu icin servisin
rem  surecini sessizce oldurur olurdu.
rem ============================================================
:AUTOSTART_RUN
call :LOAD_SETTINGS
net session >nul 2>&1
if not %errorlevel%==0 (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] AUTOSTART SKIPPED reason=NOT_ADMIN
    exit /b 1
)
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] AUTOSTART SKIPPED reason=SERVICE_INSTALLED
    exit /b 0
)
rem VPN otomatik duraklatma aciksa ve VPN zaten bagliysa winws'yi acma;
rem VPN kapaninca :VPNCHECK_BODY baslatir (vpn.paused bayragi ile).
if exist "%VPNENABLED_FILE%" (
    call :VPN_DETECT
    if "!VPN_ERR!"=="0" (
        > "%VPNSTATE_FILE%" echo !VPN_ACTIVE!
        if "!VPN_ACTIVE!"=="1" (
            > "%VPNPAUSED_FILE%" echo 1
            >> "%LOG_DIR%\app.log" echo [%date% %time%] AUTOSTART SKIPPED reason=VPN_ACTIVE which=!VPN_WHICH!
            exit /b 0
        )
    )
)
call :ENGINE_START_CORE "!CURRENT_PROFILE!" HIDDEN
if "!CORE_OK!"=="1" (
    > "%WANT_FILE%" echo 1
    >> "%LOG_DIR%\app.log" echo [%date% %time%] AUTOSTART OK profile=!CURRENT_PROFILE!
    exit /b 0
)
>> "%LOG_DIR%\app.log" echo [%date% %time%] AUTOSTART FAILED profile=!CURRENT_PROFILE! reason=!CORE_REASON!
exit /b 1

rem ============================================================
rem  WATCHDOG_RUN - 2 dakikada bir zamanlanmis gorev tarafindan
rem  (config\watchdog.vbs uzerinden, gizli pencerede) cagrilir.
rem  Sadece su durumda winws'yi yeniden baslatir:
rem    - istenen-durum bayragi (config\engine.want) VAR  ve
rem    - winws CALISMIYOR  ve  Windows servisi kurulu DEGIL.
rem  Bayrak: Baslat basarili olunca / otomatik baslatma basarili
rem  olunca olusur; Durdur, "cikista winws'yi kapat" ve Otomatik
rem  Test baslangici bayragi siler -> kullanici bilerek durdurduysa
rem  watchdog geri baslatmaz.
rem  Dongu korumasi: ust uste 3 basarisiz denemeden sonra vazgecer
rem  (config\watchdog.fails); Baslat sayaci sifirlar. Log'a SADECE
rem  bir islem yapildiginda yazar (her tikte satir eklemez).
rem ============================================================
:WATCHDOG_RUN
if not exist "%WANT_FILE%" exit /b 0
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (
    if exist "%WDFAILS_FILE%" del "%WDFAILS_FILE%" >nul 2>&1
    exit /b 0
)
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 exit /b 0
rem VPN nedeniyle duraklatildiysa (veya VPN su an bagliysa) yeniden baslatma
if exist "%VPNPAUSED_FILE%" exit /b 0
if exist "%VPNENABLED_FILE%" (
    set "VPN_PREV=0"
    if exist "%VPNSTATE_FILE%" set /p VPN_PREV=<"%VPNSTATE_FILE%"
    if "!VPN_PREV!"=="1" exit /b 0
)
set "WD_FAILS=0"
if exist "%WDFAILS_FILE%" set /p WD_FAILS=<"%WDFAILS_FILE%"
set /a WD_FAILS=WD_FAILS+0 2>nul
if !WD_FAILS! GEQ 3 exit /b 0
call :LOAD_SETTINGS
call :ENGINE_START_CORE "!CURRENT_PROFILE!" HIDDEN
if "!CORE_OK!"=="1" (
    del "%WDFAILS_FILE%" >nul 2>&1
    >> "%LOG_DIR%\app.log" echo [%date% %time%] WATCHDOG RESTART OK profile=!CURRENT_PROFILE!
    exit /b 0
)
set /a WD_FAILS+=1
> "%WDFAILS_FILE%" echo !WD_FAILS!
>> "%LOG_DIR%\app.log" echo [%date% %time%] WATCHDOG RESTART FAILED attempt=!WD_FAILS!/3 profile=!CURRENT_PROFILE! reason=!CORE_REASON!
if !WD_FAILS! GEQ 3 (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] WATCHDOG GIVING UP - press Start to re-arm
)
exit /b 1

rem ============================================================
rem  VPNCHECK_RUN - ag olayi (anlik) ve 1 dakikalik gorev tarafindan
rem  (config\vpn.vbs uzerinden, gizli pencerede) cagrilir.
rem  Uc koruma vardir (VPN baglanirken winws'nin surekli acilip
rem  kapanmasini onlemek icin):
rem   1) TEK ORNEK KILIDI: ayni anda yalnizca bir /vpncheck calisir
rem      (config\vpn.lock klasoru). Ag olaylari ust uste gelse bile
rem      digerleri hemen cikar. 300 sn'den eski kilit bayat sayilir.
rem   2) HIZLI DURDURMA: VPN gorunur gorunmez winws durdurulur
rem      (kapali->acik gecisi, vpn.state 0->1, vpn.paused konur).
rem   3) YAVAS GERI ACMA: VPN gorunmez olunca hemen acilmaz; yaklasik
rem      20 sn boyunca ~5 sn arayla tekrar bakilir, VPN bir kez bile
rem      geri gelirse vazgecilir (adaptor bir an dusup yeniden
rem      kalkabiliyor). Ancak 4 temiz kontrolden sonra vpn.state=0
rem      olur ve vpn.paused varsa winws baslatilir.
rem  VPN acikken kullanici kendi Baslat'a basarsa bu bir kullanici
rem  karari sayilir (gecis olmadigi icin karismaz). Windows servisi
rem  kuruluysa winws'yi SCM yonettigi icin taskkill yerine servis
rem  durdurulur / baslatilir (sc stop / sc start). Tespit
rem  yapilamazsa HICBIR SEY yapmaz.
rem  Cagri: ZapretTurkey.bat /vpncheck event veya poll - ikinci
rem  parametre logdaki trigger= etiketidir (hangi gorev tetikledi).
rem  Her karar logs\app.log'a nedeniyle yazilir.
rem ============================================================
:VPNCHECK_RUN
if not exist "%VPNENABLED_FILE%" exit /b 0
set "VPN_TRIGGER=%~2"
if not defined VPN_TRIGGER set "VPN_TRIGGER=manual"
rem arka plan modu: VPN_DETECT PowerShell'i yeni pencere acmadan calistirir
set "VPN_BG=1"
call :VPN_LOCK_ACQUIRE
if not "!VPN_LOCKED!"=="1" exit /b 0
call :VPNCHECK_BODY
rd /s /q "%VPNLOCK_DIR%" >nul 2>&1
exit /b 0

rem ------------------------------------------------------------
rem  NOW_SECS - gunun saniyesi (NOWS). %time% 24 saat bicimli ve
rem  tek haneli saat bosluklu olabilir; sifir ile doldurulur.
rem ------------------------------------------------------------
:NOW_SECS
for /f "tokens=1-3 delims=:., " %%a in ("%time%") do (
    set "T_H=0%%a"
    set "T_M=0%%b"
    set "T_S=0%%c"
)
set /a "NOWS=(1!T_H:~-2!-100)*3600+(1!T_M:~-2!-100)*60+(1!T_S:~-2!-100)"
exit /b 0

rem ------------------------------------------------------------
rem  VPN_LOCK_ACQUIRE - VPN_LOCKED=1 ise kilit alindi.
rem  mkdir atomiktir: klasor varsa basarisiz olur.
rem ------------------------------------------------------------
:VPN_LOCK_ACQUIRE
set "VPN_LOCKED=0"
if not exist "%ROOT%config" mkdir "%ROOT%config" >nul 2>&1
mkdir "%VPNLOCK_DIR%" >nul 2>&1
if errorlevel 1 goto VPN_LOCK_BUSY
call :NOW_SECS
> "%VPNLOCK_DIR%\t" echo !NOWS!
set "VPN_LOCKED=1"
exit /b 0

:VPN_LOCK_BUSY
set "LK_T="
if exist "%VPNLOCK_DIR%\t" set /p LK_T=<"%VPNLOCK_DIR%\t"
call :NOW_SECS
if not defined LK_T (
    > "%VPNLOCK_DIR%\t" echo !NOWS!
    exit /b 0
)
set /a LK_AGE=NOWS-LK_T
if !LK_AGE! LSS 0 set /a LK_AGE+=86400
if !LK_AGE! LEQ 300 exit /b 0
rd /s /q "%VPNLOCK_DIR%" >nul 2>&1
mkdir "%VPNLOCK_DIR%" >nul 2>&1
if errorlevel 1 exit /b 0
> "%VPNLOCK_DIR%\t" echo !NOWS!
set "VPN_LOCKED=1"
>> "%LOG_DIR%\app.log" echo [%date% %time%] VPN CHECK stale lock cleared
exit /b 0

rem ------------------------------------------------------------
rem  VPNCHECK_BODY - kilit alindiktan sonra asil karar mantigi
rem ------------------------------------------------------------
:VPNCHECK_BODY
rem ag olayi geldiginde VPN istemcisinin adaptoru Up yapmasi icin kisa bekleme
ping -n 2 127.0.0.1 >nul
call :VPN_DETECT
if "!VPN_ERR!"=="1" exit /b 0
set "VPN_PREV=0"
if exist "%VPNSTATE_FILE%" set /p VPN_PREV=<"%VPNSTATE_FILE%"
if "!VPN_ACTIVE!"=="1" goto VPNB_ACTIVE
if not "!VPN_PREV!"=="1" exit /b 0
goto VPNB_CONFIRM_OFF

rem VPN gorunuyor: gecis (0->1) ise winws'yi hemen durdur
:VPNB_ACTIVE
if "!VPN_PREV!"=="1" exit /b 0
> "%VPNSTATE_FILE%" echo 1
rem Windows servisi kuruluysa winws'yi SCM yonetir: taskkill yerine sc stop
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 goto VPNB_ACTIVE_SVC
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if not %errorlevel%==0 (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] VPN CONNECTED which=!VPN_WHICH! trigger=!VPN_TRIGGER! - winws was not running, nothing to pause
    exit /b 0
)
taskkill /F /IM winws.exe >nul 2>&1
> "%VPNPAUSED_FILE%" echo 1
>> "%LOG_DIR%\app.log" echo [%date% %time%] VPN CONNECTED which=!VPN_WHICH! trigger=!VPN_TRIGGER! - winws paused
exit /b 0

:VPNB_ACTIVE_SVC
sc query "%SVCNAME%" | find "RUNNING" >nul
if not %errorlevel%==0 (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] VPN CONNECTED which=!VPN_WHICH! trigger=!VPN_TRIGGER! - service was not running, nothing to pause
    exit /b 0
)
sc stop "%SVCNAME%" >nul 2>&1
> "%VPNPAUSED_FILE%" echo 1
>> "%LOG_DIR%\app.log" echo [%date% %time%] VPN CONNECTED which=!VPN_WHICH! trigger=!VPN_TRIGGER! - service stopped
exit /b 0

rem VPN gorunmuyor ama son bilinen durum "acik": dogrula, sonra karar ver
:VPNB_CONFIRM_OFF
set "VPN_CLEAN=1"
>> "%LOG_DIR%\app.log" echo [%date% %time%] VPN GONE trigger=!VPN_TRIGGER! - confirming for about 20 s before resuming
:VPNB_CONFIRM_LOOP
ping -n 6 127.0.0.1 >nul
call :VPN_DETECT
if "!VPN_ERR!"=="1" exit /b 0
if "!VPN_ACTIVE!"=="1" (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] VPN BACK while confirming which=!VPN_WHICH! - staying paused
    exit /b 0
)
set /a VPN_CLEAN+=1
if !VPN_CLEAN! LSS 4 goto VPNB_CONFIRM_LOOP
> "%VPNSTATE_FILE%" echo 0
if not exist "%VPNPAUSED_FILE%" (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] VPN DISCONNECTED - nothing to resume
    exit /b 0
)
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 goto VPNB_RESUME_SVC
call :LOAD_SETTINGS
call :ENGINE_START_CORE "!CURRENT_PROFILE!" HIDDEN
rem vpn.paused baslatma bitene kadar kalir: watchdog araya girmesin
del "%VPNPAUSED_FILE%" >nul 2>&1
if "!CORE_OK!"=="1" (
    > "%WANT_FILE%" echo 1
    >> "%LOG_DIR%\app.log" echo [%date% %time%] VPN DISCONNECTED - winws resumed profile=!CURRENT_PROFILE!
    exit /b 0
)
>> "%LOG_DIR%\app.log" echo [%date% %time%] VPN DISCONNECTED - resume FAILED profile=!CURRENT_PROFILE! reason=!CORE_REASON!
exit /b 1

rem Servis modu: 1056 = zaten calisiyor (kullanici elle baslatmis olabilir), sorun degil
:VPNB_RESUME_SVC
sc start "%SVCNAME%" >nul 2>&1
set "VPN_RC=!errorlevel!"
del "%VPNPAUSED_FILE%" >nul 2>&1
if "!VPN_RC!"=="0" (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] VPN DISCONNECTED - service started
    exit /b 0
)
if "!VPN_RC!"=="1056" (
    >> "%LOG_DIR%\app.log" echo [%date% %time%] VPN DISCONNECTED - service was already running
    exit /b 0
)
>> "%LOG_DIR%\app.log" echo [%date% %time%] VPN DISCONNECTED - service start FAILED rc=!VPN_RC!
exit /b 1

rem ============================================================
rem  ANA MENU
rem ============================================================
:MAIN_MENU
cls
call :LOAD_SETTINGS
call :GET_DISPLAY_NAME "!CURRENT_PROFILE!" PROFNAME
call :CHECK_RUNNING RUNSTATE
call :CHECK_SERVICE SVCSTATE

if "!RUNSTATE!"=="RUNNING" (set "RUNSTATE_DISP=%L_STATUS_RUNNING%") else (set "RUNSTATE_DISP=%L_STATUS_STOPPED%")
if "!SVCSTATE!"=="INSTALLED" (set "SVCSTATE_DISP=%L_SVC_INSTALLED%") else (set "SVCSTATE_DISP=%L_SVC_NOT_INSTALLED%")

echo %C_CYAN%============================================================%C_RESET%
echo %C_CYAN%   %L_APP_TITLE%%C_RESET%
echo %C_CYAN%============================================================%C_RESET%
if "!RUNSTATE!"=="RUNNING" (
    echo   %L_LBL_STATUS% : %C_GREEN%!RUNSTATE_DISP!%C_RESET%
) else (
    echo   %L_LBL_STATUS% : %C_RED%!RUNSTATE_DISP!%C_RESET%
)
echo   %L_LBL_PROFILE% : !CURRENT_PROFILE! (!PROFNAME!)
echo   %L_LBL_DNS_MODE% : !DNS_MODE!
echo   %L_LBL_SERVICE% : !SVCSTATE_DISP!
echo %C_CYAN%------------------------------------------------------------%C_RESET%
echo   %C_CYAN%[1]%C_RESET%  %L_MENU_START%
echo   %C_CYAN%[2]%C_RESET%  %L_MENU_STOP%
echo   %C_CYAN%[3]%C_RESET%  %L_MENU_CHANGE_PROFILE%
echo   %C_CYAN%[4]%C_RESET%  %L_MENU_AUTO_TEST%
echo   %C_CYAN%[5]%C_RESET%  %L_MENU_SERVICE_SETTINGS%
echo   %C_CYAN%[6]%C_RESET%  %L_MENU_DIAGNOSTICS%
echo   %C_CYAN%[7]%C_RESET%  %L_MENU_SETTINGS%
echo   %C_CYAN%[8]%C_RESET%  %L_MENU_LOGS%
echo   %C_CYAN%[9]%C_RESET%  %L_MENU_TOOLS%
echo   %C_CYAN%[0]%C_RESET%  %L_MENU_EXIT%
echo %C_CYAN%------------------------------------------------------------%C_RESET%
echo.
set "CH="
set /p "CH=%L_PROMPT_CHOICE% "

if "%CH%"=="1" call :START_ENGINE & goto MAIN_MENU
if "%CH%"=="2" call :STOP_ENGINE & goto MAIN_MENU
if "%CH%"=="3" call :PROFILE_MENU & goto MAIN_MENU
if "%CH%"=="4" call :AUTO_TEST & goto MAIN_MENU
if "%CH%"=="5" call :SERVICE_MENU & goto MAIN_MENU
if "%CH%"=="6" call "%ROOT%scripts\diagnostics.bat" & pause & goto MAIN_MENU
if "%CH%"=="7" call :SETTINGS_MENU & goto MAIN_MENU
if "%CH%"=="8" call :LOGS_MENU & goto MAIN_MENU
if "%CH%"=="9" call :TOOLS_MENU & goto MAIN_MENU
if "%CH%"=="0" goto END
goto MAIN_MENU

rem ============================================================
rem  CIKIS
rem ============================================================
:END
cls
sc query "%SVCNAME%" 2>nul | find "RUNNING" >nul
if %errorlevel%==0 (
    echo %L_EXIT_SERVICE_CONTINUES%
) else (
    tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
    if %errorlevel%==0 (
        choice /c YN /n /m "%L_EXIT_WINWS_STILL_RUNNING% "
        if not errorlevel 2 (
            taskkill /F /IM winws.exe >nul 2>&1
            del "%WANT_FILE%" >nul 2>&1
            del "%VPNPAUSED_FILE%" >nul 2>&1
            echo %L_EXIT_WINWS_KILLED%
        )
    )
)
echo %L_EXIT_DNS_UNTOUCHED%
echo %L_EXIT_CLOSING%
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
rem  ONEMLI: bu ayari SABIT 4 satirla YENIDEN yazar (dinamik
rem  satir eslestirme / FOR-icinde-FOR kullanilmaz). LANG satiri
rem  mevcut oturumun UI_LANG degerinden yazilir (lang-load.bat
rem  tarafindan basta yuklenmisti) - boylece profil/DNS/debug
rem  degistiginde dil secimi SILINMEZ.
rem ============================================================
:SET_SETTING
call :LOAD_SETTINGS
if /I "%~1"=="CURRENT_PROFILE" set "CURRENT_PROFILE=%~2"
if /I "%~1"=="DNS_MODE" set "DNS_MODE=%~2"
if /I "%~1"=="DEBUG" set "DEBUG=%~2"
> "%CONFIG_FILE%" echo CURRENT_PROFILE=%CURRENT_PROFILE%
>> "%CONFIG_FILE%" echo DNS_MODE=%DNS_MODE%
>> "%CONFIG_FILE%" echo DEBUG=%DEBUG%
>> "%CONFIG_FILE%" echo LANG=%UI_LANG%
exit /b

rem ============================================================
rem  YARDIMCI: profil goruntu adi
rem  1) once .conf dosyasindaki NAME= satiri okunur (varsa) - bu
rem     topluluk tarafindan eklenen yeni profillerin de bir adi
rem     olmasini saglar.
rem  2) uc yerlesik profil (stable/compatibility/strong) icin dil
rem     dosyasindaki ceviri HER ZAMAN bu adin ustune yazar - boylece
rem     dil degisince bu ucunun adi da degisir.
rem  3) hicbir kaynaktan ad bulunamazsa "Bilinmeyen profil (id)".
rem ============================================================
:GET_DISPLAY_NAME
set "gdn_id=%~1"
set "gdn_out=%~2"
set "gdn_name="
set "gdn_conf=%PROFILE_DIR%\%gdn_id%.conf"
if exist "%gdn_conf%" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%gdn_conf%") do (
        if "%%A"=="NAME" set "gdn_name=%%B"
    )
)
if /I "%gdn_id%"=="stable" set "gdn_name=!L_PROFILE_STABLE_NAME!"
if /I "%gdn_id%"=="compatibility" set "gdn_name=!L_PROFILE_COMPATIBILITY_NAME!"
if /I "%gdn_id%"=="strong" set "gdn_name=!L_PROFILE_STRONG_NAME!"
if not defined gdn_name set "gdn_name=%L_PROFILE_UNKNOWN_NAME% (%gdn_id%)"
set "%gdn_out%=%gdn_name%"
exit /b

rem ============================================================
rem  YARDIMCI: winws calisiyor mu
rem  DIL-BAGIMSIZ token dondurur (RUNNING/STOPPED) - cagiran,
rem  ekrana basmadan once bunu L_STATUS_* ile kendisi cevirir.
rem  Boylece dil degisse bile if karsilastirmalari BOZULMAZ.
rem ============================================================
:CHECK_RUNNING
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (set "%~1=RUNNING") else (set "%~1=STOPPED")
exit /b

rem ============================================================
rem  YARDIMCI: hizmet kurulu mu
rem  DIL-BAGIMSIZ token dondurur (INSTALLED/NOT_INSTALLED).
rem ============================================================
:CHECK_SERVICE
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (set "%~1=INSTALLED") else (set "%~1=NOT_INSTALLED")
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
    set "CORE_ARGS=!CORE_ARGS! --hostlist="!CORE_TARGET_FILE!""
)

rem Bilinen uyumsuzluklar icin haric tutma listesi (WhatsApp gibi -
rem hedef listede olmasa bile ekstra guvenlik).
set "CORE_EXCLUDE_FILE=%PROFILE_DIR%\exclude-hosts.txt"
if exist "%CORE_EXCLUDE_FILE%" (
    set "CORE_ARGS=!CORE_ARGS! --hostlist-exclude="!CORE_EXCLUDE_FILE!""
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

set "CORE_CMDLINE="%ENGINE_DIR%\winws.exe" --wf-tcp=!CORE_PORT! !CORE_ARGS!"

if /I "%CORE_MODE%"=="HIDDEN" (
    rem --- tamamen gizli calistirma (Otomatik Test icin) ---
    rem Hicbir pencere acilmaz/gorunmez. "start /min" bile teknik
    rem olarak bir pencere YARATIR (sadece kucultulmus) ve olusma/
    rem yok olma aninda kisa bir gorsel goruntu birakabilir. Bu VBS
    rem teknigi hicbir pencere yaratmadigi icin o goruntu de olmaz.
    > "%LOG_DIR%\_hidden_engine.bat" echo @echo off
    >> "%LOG_DIR%\_hidden_engine.bat" echo !CORE_CMDLINE! ^> "%LOG_DIR%\engine_stdout.log" 2^> "%LOG_DIR%\engine_stderr.log"
    > "%LOG_DIR%\_hidden_launcher.vbs" echo Set WshShell = CreateObject^("WScript.Shell"^)
    >> "%LOG_DIR%\_hidden_launcher.vbs" echo WshShell.Run Chr^(34^) ^& "%LOG_DIR%\_hidden_engine.bat" ^& Chr^(34^), 0, False
    wscript.exe //nologo "%LOG_DIR%\_hidden_launcher.vbs"
) else (
    rem --- ayri, gorunur pencere (Baslat menusu icin) ---
    start "ZapretTurkey" /min "%ENGINE_DIR%\winws.exe" --wf-tcp=!CORE_PORT! !CORE_ARGS! > "%LOG_DIR%\engine_stdout.log" 2> "%LOG_DIR%\engine_stderr.log"
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
set "VPN_CANCEL=0"
if exist "%VPNENABLED_FILE%" call :VPN_START_GUARD
if "!VPN_CANCEL!"=="1" exit /b
call :LOAD_SETTINGS
call :ENGINE_START_CORE "!CURRENT_PROFILE!"

if "!CORE_OK!"=="1" (
    echo %C_GREEN%%L_START_OK%%C_RESET%
    echo %L_START_CMDLINE_LABEL% !CORE_CMDLINE!
    echo %L_START_RESTART_HINT%
    >> "%LOG_DIR%\app.log" echo [%date% %time%] START OK profile=!CURRENT_PROFILE!
    > "%WANT_FILE%" echo 1
    del "%WDFAILS_FILE%" >nul 2>&1
    del "%VPNPAUSED_FILE%" >nul 2>&1
    pause
    exit /b
)

echo %C_RED%!L_START_FAILED!%C_RESET%
echo !L_START_FAILED_PROFILE_LABEL! !CURRENT_PROFILE!
echo !L_START_FAILED_REASON_LABEL! !CORE_REASON!
if "!CORE_REASON!"=="PROFILE_NOT_FOUND" (
    echo !L_START_FAILED_PATH_LABEL! !CORE_CONFPATH!
)
if "!CORE_REASON!"=="PROFILE_PARSE_FAILED" (
    echo !L_START_FAILED_PATH_LABEL! !CORE_CONFPATH!
    echo !L_REASON_PROFILE_PARSE_FAILED_HINT!
)
if "!CORE_REASON!"=="ENGINE_MISSING" (
    echo !L_REASON_ENGINE_MISSING_HINT! !ENGINE_DIR!\winws.exe
)
if "!CORE_REASON!"=="WINDIVERT_MISSING" (
    echo !L_REASON_WINDIVERT_MISSING_HINT!
)
if "!CORE_REASON!"=="NOT_ADMIN" (
    echo !L_REASON_NOT_ADMIN_HINT!
)
if "!CORE_REASON!"=="ENGINE_EXITED" (
    echo !L_REASON_ENGINE_EXITED_CMDLINE_LABEL! !CORE_CMDLINE!
    echo !L_REASON_ENGINE_EXITED_STDERR_LABEL! !CORE_STDERR_TAIL!
    echo !L_REASON_ENGINE_EXITED_FULL_LOG! !LOG_DIR!\engine_stderr.log
)
if "!CORE_REASON!"=="UNKNOWN_STATE" (
    echo !L_REASON_UNKNOWN_STATE_1!
    echo !L_REASON_UNKNOWN_STATE_2!
)
>> "%LOG_DIR%\app.log" echo [%date% %time%] START FAILED profile=!CURRENT_PROFILE! reason=!CORE_REASON!
echo.
pause
exit /b

rem ============================================================
rem  DURDUR
rem ============================================================
:STOP_ENGINE
del "%WANT_FILE%" >nul 2>&1
del "%VPNPAUSED_FILE%" >nul 2>&1
taskkill /F /IM winws.exe >nul 2>&1
if %errorlevel%==0 (
    echo %C_GREEN%%L_STOP_OK%%C_RESET%
    >> "%LOG_DIR%\app.log" echo [%date% %time%] STOP
) else (
    echo %C_GRAY%%L_STOP_ALREADY_STOPPED%%C_RESET%
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
echo %L_CHANGE_PROFILE_PROMPT%
echo.
echo   [1] stable        - !N1!
echo   [2] compatibility - !N2!
echo   [3] strong        - !N3!
echo   [0] %L_CHANGE_PROFILE_CANCEL%
echo.
set "PC="
set /p "PC=%L_PROMPT_CHOICE% "
set "NEWP="
if "%PC%"=="1" set "NEWP=stable"
if "%PC%"=="2" set "NEWP=compatibility"
if "%PC%"=="3" set "NEWP=strong"
if not defined NEWP exit /b

call :SET_SETTING CURRENT_PROFILE !NEWP!
echo %C_GREEN%%L_CHANGE_PROFILE_DONE% !NEWP!%C_RESET%

tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (
    choice /c YN /n /m "%L_CHANGE_PROFILE_RESTART_PROMPT% "
    if not errorlevel 2 call :START_ENGINE
)

sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (
    echo %C_YELLOW%%L_CHANGE_PROFILE_SERVICE_NOTE_1%%C_RESET%
    echo %C_YELLOW%%L_CHANGE_PROFILE_SERVICE_NOTE_2%%C_RESET%
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
echo %C_CYAN%%L_AUTOTEST_TITLE%%C_RESET%
echo %L_AUTOTEST_INFO_1%
echo %L_AUTOTEST_INFO_2%
echo %L_AUTOTEST_INFO_3%
echo !L_AUTOTEST_INFO_4!
echo.
where curl >nul 2>&1
if not %errorlevel%==0 (
    echo %C_RED%%L_AUTOTEST_CURL_MISSING%%C_RESET%
    pause
    exit /b
)
choice /c YN /n /m "%L_AUTOTEST_CONTINUE_PROMPT% "
if errorlevel 2 exit /b
rem Otomatik Test calisirken watchdog araya girmesin: istenen-durum bayragi silinir
del "%WANT_FILE%" >nul 2>&1
del "%VPNPAUSED_FILE%" >nul 2>&1

set "RESULT_stable=SKIP"
set "RESULT_compatibility=SKIP"
set "RESULT_strong=SKIP"

call :RUN_AUTOTEST_ONE stable
call :RUN_AUTOTEST_ONE compatibility
call :RUN_AUTOTEST_ONE strong

taskkill /F /IM winws.exe >nul 2>&1

echo.
echo %C_CYAN%================= %L_AUTOTEST_RESULTS_TITLE% =================%C_RESET%
echo   %L_AUTOTEST_RESULT_STABLE% !RESULT_stable!
echo   %L_AUTOTEST_RESULT_COMPAT% !RESULT_compatibility!
echo   %L_AUTOTEST_RESULT_STRONG% !RESULT_strong!
echo %C_CYAN%==========================================%C_RESET%

set "WINNER="
if "!RESULT_stable!"=="PASS" set "WINNER=stable"
if not defined WINNER if "!RESULT_compatibility!"=="PASS" set "WINNER=compatibility"
if not defined WINNER if "!RESULT_strong!"=="PASS" set "WINNER=strong"

if defined WINNER call :GET_DISPLAY_NAME !WINNER! WN

if defined WINNER (
    echo.
    echo %C_GREEN%%L_AUTOTEST_RECOMMENDED% !WINNER! ^(!WN!^)%C_RESET%
) else (
    echo.
    echo %C_RED%%L_AUTOTEST_NONE_PASSED%%C_RESET%
    echo !L_AUTOTEST_NONE_PASSED_HINT!
)

set "SAVE_CH=0"
if defined WINNER (
    choice /c YN /n /m "%L_AUTOTEST_SAVE_PROMPT% "
    set "SAVE_CH=!errorlevel!"
)
if "!SAVE_CH!"=="1" call :SET_SETTING CURRENT_PROFILE !WINNER!
if "!SAVE_CH!"=="1" echo %L_AUTOTEST_SAVED%

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
echo %C_CYAN%%L_AUTOTEST_TESTING_LABEL% %RA_ID% (%RA_NAME%) ---%C_RESET%

call :SET_SETTING CURRENT_PROFILE %RA_ID%
call :ENGINE_START_CORE %RA_ID% HIDDEN

if not "!CORE_OK!"=="1" (
    echo %C_RED%!L_AUTOTEST_START_FAILED_LABEL! !CORE_REASON!%C_RESET%
    set "RESULT_%RA_ID%=FAIL"
    exit /b
)

echo %L_AUTOTEST_CONNECTING%
call :TEST_ENDPOINTS RA_TESTRESULT
taskkill /F /IM winws.exe >nul 2>&1

if "!RA_TESTRESULT!"=="OK" (
    echo %C_GREEN%%L_AUTOTEST_PASS%%C_RESET%
    set "RESULT_%RA_ID%=PASS"
) else (
    echo %C_RED%!L_AUTOTEST_FAIL!%C_RESET%
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
if "!SVCSTATE!"=="INSTALLED" (set "SVCSTATE_DISP=%L_SVC_INSTALLED%") else (set "SVCSTATE_DISP=%L_SVC_NOT_INSTALLED%")
call :CHECK_AUTOSTART ASSTATE
if "!ASSTATE!"=="ON" (set "ASTATE_DISP=!L_ASTART_ON!") else (set "ASTATE_DISP=!L_ASTART_OFF!")
call :CHECK_WATCHDOG WDSTATE
if "!WDSTATE!"=="ON" (set "WDSTATE_DISP=!L_ASTART_ON!") else (set "WDSTATE_DISP=!L_ASTART_OFF!")
call :CHECK_VPN VPNCHK
if "!VPNCHK!"=="ON" (set "VPNST_DISP=!L_ASTART_ON!") else (set "VPNST_DISP=!L_ASTART_OFF!")
echo %C_CYAN%============================================================%C_RESET%
echo   %L_SVC_MENU_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo   %L_SVC_MENU_STATUS_LABEL% !SVCSTATE_DISP!
echo   !L_ASTART_STATUS_LABEL! !ASTATE_DISP!
echo   !L_WDOG_STATUS_LABEL! !WDSTATE_DISP!
echo   !L_VPN_STATUS_LABEL! !VPNST_DISP!
echo.
echo   !L_SVC_MENU_INSTALL!
echo   %L_SVC_MENU_UNINSTALL%
echo   %L_SVC_MENU_START%
echo   %L_SVC_MENU_STOP%
echo   !L_SVC_MENU_ASTART_ON!
echo   !L_SVC_MENU_ASTART_OFF!
echo   !L_SVC_MENU_WDOG_ON!
echo   !L_SVC_MENU_WDOG_OFF!
echo   !L_SVC_MENU_VPN_ON!
echo   !L_SVC_MENU_VPN_OFF!
echo   %L_SVC_MENU_BACK%
echo.
set "SVC="
set /p "SVC=%L_PROMPT_CHOICE% "
if "%SVC%"=="1" call "%ROOT%scripts\install-service.bat"
if "%SVC%"=="2" call "%ROOT%scripts\uninstall-service.bat"
if "%SVC%"=="3" (sc start "%SVCNAME%" & pause)
if "%SVC%"=="4" (sc stop "%SVCNAME%" & pause)
if "%SVC%"=="5" (call :AUTOSTART_ENABLE & pause)
if "%SVC%"=="6" (call :AUTOSTART_DISABLE & pause)
if "%SVC%"=="7" (call :WATCHDOG_ENABLE & pause)
if "%SVC%"=="8" (call :WATCHDOG_DISABLE & pause)
if "%SVC%"=="9" (call :VPN_ENABLE & pause)
if "%SVC%"=="10" (call :VPN_DISABLE & pause)
exit /b

rem ============================================================
rem  GIRISTE OTOMATIK BASLATMA (servis kurmadan)
rem  Oturum acilisinda, yuksek yetkiyle calisan bir zamanlanmis
rem  gorev olusturur. Gorev dogrudan .bat'i calistirsa her giriste
rem  birkac saniye siyah cmd penceresi gorunurdu; bu yuzden
rem  config\autostart.vbs (pencere stili 0 = gizli) uzerinden
rem  "ZapretTurkey.bat /autostart" cagirir. Windows servisi
rem  kuruluyken ACILMAZ (bkz. :AUTOSTART_RUN aciklamasi).
rem ============================================================
:CHECK_AUTOSTART
schtasks /query /tn "%ASTASK%" >nul 2>&1
if %errorlevel%==0 (set "%~1=ON") else (set "%~1=OFF")
exit /b

:AUTOSTART_ENABLE
echo.
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (
    echo %C_YELLOW%!L_ASTART_SERVICE_CONFLICT!%C_RESET%
    exit /b
)
set "AS_VBS=%ROOT%config\autostart.vbs"
if not exist "%ROOT%config" mkdir "%ROOT%config" >nul 2>&1
> "%AS_VBS%" echo Set sh = CreateObject^("WScript.Shell"^)
>> "%AS_VBS%" echo sh.Run "cmd /c " ^& Chr^(34^) ^& Chr^(34^) ^& "%ROOT%ZapretTurkey.bat" ^& Chr^(34^) ^& " /autostart" ^& Chr^(34^), 0, False
schtasks /create /tn "%ASTASK%" /tr "wscript.exe //nologo \"%AS_VBS%\"" /sc onlogon /rl highest /delay 0000:15 /f >nul 2>&1
if errorlevel 1 (
    echo %C_RED%!L_ASTART_FAILED!%C_RESET%
    del "%AS_VBS%" >nul 2>&1
    exit /b
)
echo %C_GREEN%!L_ASTART_ENABLED!%C_RESET%
echo !L_ASTART_NOTE!
exit /b

:AUTOSTART_DISABLE
echo.
call :CHECK_AUTOSTART ASCHK
if "!ASCHK!"=="OFF" (
    echo !L_ASTART_ALREADY_OFF!
    del "%ROOT%config\autostart.vbs" >nul 2>&1
    exit /b
)
schtasks /delete /tn "%ASTASK%" /f >nul 2>&1
if errorlevel 1 (
    echo %C_RED%!L_ASTART_DELETE_FAILED!%C_RESET%
    exit /b
)
del "%ROOT%config\autostart.vbs" >nul 2>&1
echo %C_GREEN%!L_ASTART_DISABLED!%C_RESET%
exit /b

rem ============================================================
rem  WATCHDOG (winws beklenmedik sekilde kapanirsa yeniden baslat)
rem  2 dakikada bir calisan, yuksek yetkili zamanlanmis gorev.
rem  Gorev config\watchdog.vbs (gizli) uzerinden
rem  "ZapretTurkey.bat /watchdog" cagirir (bkz. :WATCHDOG_RUN).
rem  Windows servisi kuruluyken ACILMAZ.
rem ============================================================
:CHECK_WATCHDOG
schtasks /query /tn "%WDTASK%" >nul 2>&1
if %errorlevel%==0 (set "%~1=ON") else (set "%~1=OFF")
exit /b

:WATCHDOG_ENABLE
echo.
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (
    echo %C_YELLOW%!L_WDOG_SERVICE_CONFLICT!%C_RESET%
    exit /b
)
set "WD_VBS=%ROOT%config\watchdog.vbs"
if not exist "%ROOT%config" mkdir "%ROOT%config" >nul 2>&1
> "%WD_VBS%" echo Set sh = CreateObject^("WScript.Shell"^)
>> "%WD_VBS%" echo sh.Run "cmd /c " ^& Chr^(34^) ^& Chr^(34^) ^& "%ROOT%ZapretTurkey.bat" ^& Chr^(34^) ^& " /watchdog" ^& Chr^(34^), 0, False
schtasks /create /tn "%WDTASK%" /tr "wscript.exe //nologo \"%WD_VBS%\"" /sc minute /mo 2 /rl highest /f >nul 2>&1
if errorlevel 1 (
    echo %C_RED%!L_WDOG_FAILED!%C_RESET%
    del "%WD_VBS%" >nul 2>&1
    exit /b
)
del "%WDFAILS_FILE%" >nul 2>&1
rem winws zaten calisiyorsa onu da koru: istenen-durum bayragini olustur
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (
    > "%WANT_FILE%" echo 1
)
echo %C_GREEN%!L_WDOG_ENABLED!%C_RESET%
echo !L_WDOG_NOTE!
exit /b

:WATCHDOG_DISABLE
echo.
call :CHECK_WATCHDOG WDCHK
if "!WDCHK!"=="OFF" (
    echo !L_WDOG_ALREADY_OFF!
    del "%ROOT%config\watchdog.vbs" >nul 2>&1
    exit /b
)
schtasks /delete /tn "%WDTASK%" /f >nul 2>&1
if errorlevel 1 (
    echo %C_RED%!L_WDOG_DELETE_FAILED!%C_RESET%
    exit /b
)
del "%ROOT%config\watchdog.vbs" >nul 2>&1
del "%WDFAILS_FILE%" >nul 2>&1
del "%WANT_FILE%" >nul 2>&1
echo %C_GREEN%!L_WDOG_DISABLED!%C_RESET%
exit /b

rem ============================================================
rem  VPN OTOMATIK DURAKLATMA
rem  Herhangi bir VPN baglaninca winws'yi durdurur, VPN kapaninca
rem  yeniden baslatir (bkz. :VPNCHECK_RUN). Iki zamanlanmis gorev:
rem  ag olayi (anlik, ana yol) + 5 dakikalik yedek yoklama. Ikisi de
rem  config\vpn.vbs (gizli) uzerinden ZapretTurkey.bat /vpncheck
rem  event veya poll cagirir. Windows servisi kuruluysa servis
rem  durdurulur / baslatilir (sc stop / sc start), degilse winws.
rem ============================================================

rem ------------------------------------------------------------
rem  VPN_DETECT - VPN baglantisini tespit eder
rem  Cikti: VPN_ACTIVE (0/1), VPN_WHICH (adaptor adlari),
rem         VPN_ERR=1 ise tespit YAPILAMADI (hicbir sey varsayma).
rem  Ham sonuc %TEMP%\zt_vpn.txt'e yazilir:  TUR|SONUC|AD|ACIKLAMA
rem  SONUC: VPN / WG-IGNORED (resmi WireGuard uygulamasi) / OTHER
rem  Yontem: sadece Status=Up adaptorlere bakar; aciklama/ad VPN
rem  anahtar kelimelerine uyuyorsa ve haric listede degilse VPN sayar.
rem  Resmi WireGuard uygulamasi her tunel icin WireGuardTunnel$<ad>
rem  hizmeti kurar; adaptor adi bu hizmetle eslesirse VPN SAYILMAZ.
rem  Windows'un kendi VPN baglantilari (IKEv2/L2TP vb.) da bakilir.
rem  Menuden (elle) cagrilirsa PowerShell AYRI kucultulmus pencerede
rem  calisir (konsol yazi tipini bozmasin). Arka planda (/vpncheck,
rem  VPN_BG=1) ise start KULLANILMAZ: start /min her seferinde yeni
rem  bir konsol penceresi yaratir ve gorev cubugunda titremeye yol
rem  acar. Dogrudan cagrilan PowerShell, gizli cmd'nin konsolunu
rem  kullanir, hicbir pencere gorunmez.
rem  DIKKAT: PowerShell satirinda ! karakteri KULLANMA (gecikmeli
rem  genisleme yer).
rem ------------------------------------------------------------
:VPN_DETECT
set "VPN_ACTIVE=0"
set "VPN_WHICH="
set "VPN_ERR=0"
set "ZT_VPN_OUT=%TEMP%\zt_vpn.txt"
del "%ZT_VPN_OUT%" >nul 2>&1
set "ZT_VPN_INCLUDE=TAP-|Wintun|OpenVPN|WireGuard|NordLynx|Proton|Windscribe|Mullvad|Surfshark|ExpressVPN|Express VPN|CyberGhost|Private Internet Access|TunnelBear|Cloudflare WARP|SoftEther|Fortinet|AnyConnect|GlobalProtect|PANGP|VPN"
set "ZT_VPN_EXCLUDE=Hyper-V|vEthernet|VirtualBox|VMware|Loopback|Bluetooth|Teredo|6to4|ISATAP|Wi-Fi Direct|Npcap|WSL|Docker|Virtual Switch|Miniport"
set ZT_PS_LAUNCH=
if not "%VPN_BG%"=="1" set ZT_PS_LAUNCH=start "" /wait /min
%ZT_PS_LAUNCH% powershell -NoProfile -WindowStyle Hidden -Command "try { $ErrorActionPreference = 'Stop'; $wg = @(Get-Service -Name 'WireGuardTunnel$*' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name.Substring(16) }); $out = @(); foreach ($a in @(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })) { $n = [string]$a.Name; $d = [string]$a.InterfaceDescription; if ([string]::IsNullOrEmpty($d)) { $d = '-' }; $v = 'OTHER'; if ((($d -match $env:ZT_VPN_INCLUDE) -or ($n -match $env:ZT_VPN_INCLUDE)) -and -not ($d -match $env:ZT_VPN_EXCLUDE)) { $v = 'VPN'; if ($wg -contains $n) { $v = 'WG-IGNORED' } }; $out += ('ADAPTER|' + $v + '|' + $n + '|' + $d) }; foreach ($c in (@(Get-VpnConnection -AllUserConnection -ErrorAction SilentlyContinue) + @(Get-VpnConnection -ErrorAction SilentlyContinue))) { if ($c.ConnectionStatus -eq 'Connected') { $out += ('RAS|VPN|' + $c.Name + '|Windows VPN connection') } }; [System.IO.File]::WriteAllLines($env:ZT_VPN_OUT, [string[]]$out) } catch { [System.IO.File]::WriteAllText($env:ZT_VPN_OUT, 'ERR') }" >nul 2>&1
if not exist "%ZT_VPN_OUT%" (
    set "VPN_ERR=1"
    exit /b
)
for /f "usebackq tokens=1,2,3* delims=|" %%A in (`type "%ZT_VPN_OUT%" 2^>nul`) do (
    if /I "%%A"=="ERR" set "VPN_ERR=1"
    if /I "%%B"=="VPN" (
        set "VPN_ACTIVE=1"
        if defined VPN_WHICH (set "VPN_WHICH=!VPN_WHICH!, %%C") else (set "VPN_WHICH=%%C")
    )
)
exit /b

rem Baslat menusu: VPN bagliysa uyar, devam etmek icin onay iste
:VPN_START_GUARD
echo !L_VPN_CHECKING!
call :VPN_DETECT
if not "!VPN_ACTIVE!"=="1" exit /b
echo %C_YELLOW%!L_VPN_START_WARN! !VPN_WHICH!%C_RESET%
choice /c YN /n /m "!L_VPN_START_PROMPT! "
if errorlevel 2 (
    set "VPN_CANCEL=1"
    echo !L_VPN_START_CANCELLED!
    pause
)
exit /b

rem Araclar [4]: algilama sonucunu ve gorulen adaptorleri gosterir
:VPN_TEST
cls
echo %C_CYAN%============================================================%C_RESET%
echo   %L_VPNTEST_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo !L_VPNTEST_RUNNING!
call :VPN_DETECT
if "!VPN_ERR!"=="1" (
    echo %C_RED%!L_VPNTEST_ERROR!%C_RESET%
    pause
    exit /b
)
echo.
echo !L_VPNTEST_LEGEND!
echo.
set "VPN_ANYLINE=0"
for /f "usebackq tokens=1,2,3* delims=|" %%A in (`type "%ZT_VPN_OUT%" 2^>nul`) do (
    set "VPN_ANYLINE=1"
    echo   [%%B] %%C - %%D
)
if "!VPN_ANYLINE!"=="0" echo   !L_VPNTEST_NO_ADAPTERS!
echo.
if "!VPN_ACTIVE!"=="1" (
    echo %C_YELLOW%!L_VPNTEST_RESULT_ON! !VPN_WHICH!%C_RESET%
) else (
    echo %C_GREEN%!L_VPNTEST_RESULT_OFF!%C_RESET%
)
echo.
echo !L_VPNTEST_HELP!
pause
exit /b

:CHECK_VPN
schtasks /query /tn "%VPNTASK_POLL%" >nul 2>&1
if %errorlevel%==0 (set "%~1=ON") else (set "%~1=OFF")
exit /b

:VPN_ENABLE
echo.
set "VPN_VBS=%ROOT%config\vpn.vbs"
if not exist "%ROOT%config" mkdir "%ROOT%config" >nul 2>&1
rem vpn.vbs gorevden gelen ilk argumani (event veya poll) bat'a /vpncheck etiketi olarak iletir
> "%VPN_VBS%" echo Set sh = CreateObject^("WScript.Shell"^)
>> "%VPN_VBS%" echo t = "manual"
>> "%VPN_VBS%" echo If WScript.Arguments.Count ^> 0 Then t = WScript.Arguments^(0^)
>> "%VPN_VBS%" echo sh.Run "cmd /c " ^& Chr^(34^) ^& Chr^(34^) ^& "%ROOT%ZapretTurkey.bat" ^& Chr^(34^) ^& " /vpncheck " ^& t ^& Chr^(34^), 0, False
schtasks /create /tn "%VPNTASK_POLL%" /tr "wscript.exe //nologo \"%VPN_VBS%\" poll" /sc minute /mo 5 /rl highest /f >nul 2>&1
if errorlevel 1 (
    echo %C_RED%!L_VPN_FAILED!%C_RESET%
    del "%VPN_VBS%" >nul 2>&1
    exit /b
)
schtasks /create /tn "%VPNTASK_EVT%" /tr "wscript.exe //nologo \"%VPN_VBS%\" event" /sc onevent /ec "Microsoft-Windows-NetworkProfile/Operational" /mo "*[System[(EventID=10000 or EventID=10001)]]" /rl highest /f >nul 2>&1
if errorlevel 1 (
    echo %C_YELLOW%!L_VPN_EVENT_WARN!%C_RESET%
)
> "%VPNENABLED_FILE%" echo 1
del "%VPNSTATE_FILE%" >nul 2>&1
del "%VPNPAUSED_FILE%" >nul 2>&1
rd /s /q "%VPNLOCK_DIR%" >nul 2>&1
rem hemen bir kontrol calistir (VPN zaten bagliysa beklemeden duraklatsin)
schtasks /run /tn "%VPNTASK_POLL%" >nul 2>&1
echo %C_GREEN%!L_VPN_ENABLED!%C_RESET%
echo !L_VPN_NOTE!
exit /b

:VPN_DISABLE
echo.
call :CHECK_VPN VPNCHK2
if "!VPNCHK2!"=="OFF" (
    echo !L_VPN_ALREADY_OFF!
    del "%VPNENABLED_FILE%" >nul 2>&1
    del "%ROOT%config\vpn.vbs" >nul 2>&1
    exit /b
)
schtasks /delete /tn "%VPNTASK_POLL%" /f >nul 2>&1
if errorlevel 1 (
    echo %C_RED%!L_VPN_DELETE_FAILED!%C_RESET%
    exit /b
)
schtasks /delete /tn "%VPNTASK_EVT%" /f >nul 2>&1
set "VPN_WASPAUSED=0"
if exist "%VPNPAUSED_FILE%" set "VPN_WASPAUSED=1"
del "%VPNENABLED_FILE%" >nul 2>&1
del "%VPNSTATE_FILE%" >nul 2>&1
del "%VPNPAUSED_FILE%" >nul 2>&1
rd /s /q "%VPNLOCK_DIR%" >nul 2>&1
del "%ROOT%config\vpn.vbs" >nul 2>&1
echo %C_GREEN%!L_VPN_DISABLED!%C_RESET%
if "!VPN_WASPAUSED!"=="1" echo !L_VPN_DISABLED_PAUSED!
exit /b

rem ============================================================
rem  AYARLAR (DNS, Debug)
rem ============================================================
:SETTINGS_MENU
cls
call :LOAD_SETTINGS
echo %C_CYAN%============================================================%C_RESET%
echo   %L_SETTINGS_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo   %L_SETTINGS_DNS_LABEL% !DNS_MODE!   !L_SETTINGS_DNS_DEFAULT_NOTE!
echo   %L_SETTINGS_DEBUG_LABEL% !DEBUG!
echo   %L_SETTINGS_LANG_LABEL% !UI_LANG!
echo.
echo   !L_SETTINGS_OPT_DNS_LEAVE!
echo   !L_SETTINGS_OPT_DNS_CLOUDFLARE!
echo   !L_SETTINGS_OPT_DNS_DHCP!
echo   %L_SETTINGS_OPT_DEBUG_TOGGLE%
echo   !L_SETTINGS_OPT_LANG!
echo   %L_SETTINGS_BACK%
echo.
set "SS="
set /p "SS=%L_PROMPT_CHOICE% "
if "%SS%"=="1" (
    call :SET_SETTING DNS_MODE system
    echo %L_SETTINGS_DNS_TAG_UPDATED%
)
if "%SS%"=="2" call :DNS_ASSIST
if "%SS%"=="3" call :DNS_RESET_DHCP
if "%SS%"=="4" call :TOGGLE_DEBUG
if "%SS%"=="5" call "%ROOT%scripts\lang-load.bat" SWITCH
pause
exit /b

rem ============================================================
rem  NOT: dil degistirme (eski [5] secenegi) artik ayri bir
rem  :CHANGE_LANG etiketi olarak burada TUTULMUYOR. Bunun yerine
rem  yukaridaki satir dogrudan scripts\lang-load.bat'i "SWITCH"
rem  parametresiyle cagiriyor - ilk acilista zaten calistigi
rem  dogrulanmis olan AYNI dil secim/kaydetme rutinini tekrar
rem  kullanir. Boylece mantik iki yerde COPYALANMAZ.
rem ============================================================

rem ============================================================
rem  DNS_DETECT_ADAPTER
rem  Aktif (bagli, IPv4 adresi olan) ag adaptorlerini ipconfig
rem  ciktisindan tarar. "Ethernet adapter X:" / "Wireless LAN
rem  adapter X:" gibi basliklardan gercek netsh adini cikarir.
rem  Tek aday varsa onu, birden fazlaysa kullanicinin secimini,
rem  hic yoksa bos deger doner (cagiran manuel girise duser).
rem  DIKKAT: sadece Ingilizce "ipconfig" ciktisiyla test edildi -
rem  Windows arayuzu baska dildeyse otomatik tespit calismayabilir,
rem  bu yuzden her zaman bir manuel giris secenegi de sunulur.
rem  Cikti: DNSA_ADAPTER (secilen adaptor adi, bos ise bulunamadi)
rem         DNSA_HAS_V6 (1 = bu adaptorde gercek/kucal olmayan bir
rem         IPv6 adresi var, 0 = yok)
rem ============================================================
:DNS_DETECT_ADAPTER
set "DNSA_ADAPTER="
set "DNSA_HAS_V6=0"
set "DNSA_COUNT=0"
set "DNSA_CUR="
set "DNSA_CUR_ACTIVE=0"
set "DNSA_CUR_V6=0"
for /f "usebackq delims=" %%L in (`ipconfig`) do (
    set "LN=%%L"
    set "ISHDR=0"
    set "NM=!LN:Ethernet adapter =!"
    if not "!NM!"=="!LN!" set "ISHDR=1"
    if "!ISHDR!"=="0" (
        set "NM=!LN:Wireless LAN adapter =!"
        if not "!NM!"=="!LN!" set "ISHDR=1"
    )
    if "!ISHDR!"=="0" (
        set "NM=!LN:Tunnel adapter =!"
        if not "!NM!"=="!LN!" set "ISHDR=1"
    )
    if "!ISHDR!"=="1" (
        if "!DNSA_CUR_ACTIVE!"=="1" if defined DNSA_CUR (
            set /a DNSA_COUNT+=1
            set "DNSA_NAME_!DNSA_COUNT!=!DNSA_CUR!"
            set "DNSA_V6_!DNSA_COUNT!=!DNSA_CUR_V6!"
        )
        set "DNSA_CUR_ACTIVE=0"
        set "DNSA_CUR_V6=0"
        if "!NM:~-1!"==":" set "NM=!NM:~0,-1!"
        set "DNSA_CUR=!NM!"
    ) else (
        echo !LN! | findstr /c:"IPv4 Address" >nul
        if !errorlevel!==0 set "DNSA_CUR_ACTIVE=1"
        echo !LN! | findstr /c:"IPv6 Address" >nul
        if !errorlevel!==0 (
            echo !LN! | findstr /c:"Link-local" >nul
            if not !errorlevel!==0 set "DNSA_CUR_V6=1"
        )
    )
)
if "!DNSA_CUR_ACTIVE!"=="1" if defined DNSA_CUR (
    set /a DNSA_COUNT+=1
    set "DNSA_NAME_!DNSA_COUNT!=!DNSA_CUR!"
    set "DNSA_V6_!DNSA_COUNT!=!DNSA_CUR_V6!"
)
if "!DNSA_COUNT!"=="0" exit /b
if "!DNSA_COUNT!"=="1" (
    set "DNSA_ADAPTER=!DNSA_NAME_1!"
    set "DNSA_HAS_V6=!DNSA_V6_1!"
    exit /b
)
echo !L_DNS_ASSIST_FOUND_MULTI!
for /l %%I in (1,1,!DNSA_COUNT!) do (
    echo   [%%I] !DNSA_NAME_%%I!
)
echo   [0] !L_DNS_ASSIST_MANUAL_FALLBACK!
set "DNSA_PICK="
set /p "DNSA_PICK=!L_PROMPT_CHOICE! "
if "!DNSA_PICK!"=="0" exit /b
if not defined DNSA_NAME_!DNSA_PICK! exit /b
call set "DNSA_ADAPTER=%%DNSA_NAME_!DNSA_PICK!%%"
call set "DNSA_HAS_V6=%%DNSA_V6_!DNSA_PICK!%%"
exit /b

rem ============================================================
rem  DNS_ASSIST
rem  Eskiden sadece Cloudflare/manuel adaptor adi olan akisin
rem  yerine gecti: adaptoru otomatik bulmaya calisir (bulamazsa
rem  eski manuel listeleme + isim girisine duser), Cloudflare/
rem  Google sordurur, gercek IPv6 varsa IPv6 DNS'i de sorar,
rem  uyguladiktan sonra flushdns + nslookup ile dogrular.
rem ============================================================
:DNS_ASSIST
echo.
echo %C_YELLOW%!L_DNS_CLOUDFLARE_WARN!%C_RESET%
echo !L_DNS_CLOUDFLARE_INFO_1!
echo !L_DNS_CLOUDFLARE_INFO_2!
echo.
echo !L_DNS_ASSIST_DETECTING!
call :DNS_DETECT_ADAPTER
if defined DNSA_ADAPTER (
    echo !L_DNS_ASSIST_FOUND_ONE! !DNSA_ADAPTER!
    choice /c YN /n /m "'!DNSA_ADAPTER!' - !L_DNS_CLOUDFLARE_CONFIRM! "
    if errorlevel 2 set "DNSA_ADAPTER="
)
if not defined DNSA_ADAPTER (
    echo !L_DNS_ASSIST_NONE_FOUND!
    netsh interface show interface
    echo.
    set "DNSA_ADAPTER="
    set /p "DNSA_ADAPTER=!L_DNS_ASSIST_MANUAL_FALLBACK! "
    if "!DNSA_ADAPTER!"=="" exit /b
    set "DNSA_HAS_V6=0"
)

echo.
echo !L_DNS_PROVIDER_PROMPT!
echo   !L_DNS_PROVIDER_CLOUDFLARE!
echo   !L_DNS_PROVIDER_GOOGLE!
echo   !L_DNS_PROVIDER_CANCEL!
set "DNSA_PROV="
set /p "DNSA_PROV=!L_PROMPT_CHOICE! "
if "!DNSA_PROV!"=="1" (
    set "DNSA_P1=1.1.1.1"
    set "DNSA_P2=1.0.0.1"
    set "DNSA_P6A=2606:4700:4700::1111"
    set "DNSA_P6B=2606:4700:4700::1001"
    set "DNSA_TAG=cloudflare"
) else if "!DNSA_PROV!"=="2" (
    set "DNSA_P1=8.8.8.8"
    set "DNSA_P2=8.8.4.4"
    set "DNSA_P6A=2001:4860:4860::8888"
    set "DNSA_P6B=2001:4860:4860::8844"
    set "DNSA_TAG=google"
) else (
    exit /b
)

set "DNSA_DO_V6=0"
if "!DNSA_HAS_V6!"=="1" (
    echo !L_DNS_IPV6_DETECTED!
    choice /c YN /n /m "!L_DNS_IPV6_OFFER_PROMPT! "
    if not errorlevel 2 set "DNSA_DO_V6=1"
) else (
    echo !L_DNS_IPV6_NONE!
)

echo !L_DNS_ASSIST_APPLYING!
netsh interface ip set dns name="!DNSA_ADAPTER!" static !DNSA_P1! primary
netsh interface ip add dns name="!DNSA_ADAPTER!" !DNSA_P2! index=2
if "!DNSA_DO_V6!"=="1" (
    netsh interface ipv6 set dns name="!DNSA_ADAPTER!" static !DNSA_P6A! primary
    netsh interface ipv6 add dns name="!DNSA_ADAPTER!" !DNSA_P6B! index=2
)
call :SET_SETTING DNS_MODE !DNSA_TAG!
echo %C_GREEN%!L_DNS_CLOUDFLARE_DONE!%C_RESET%
>> "%LOG_DIR%\app.log" echo [%date% %time%] DNS SET !DNSA_TAG! adapter="!DNSA_ADAPTER!" ipv6=!DNSA_DO_V6!

echo.
echo !L_DNS_ASSIST_VERIFY_TITLE!
ipconfig /flushdns >nul
set "DNSA_VERIFY="
set "DNSA_SEENNAME=0"
for /f "usebackq delims=" %%L in (`nslookup discord.com !DNSA_P1! 2^>nul`) do (
    set "DVL=%%L"
    if "!DNSA_SEENNAME!"=="0" (
        echo !DVL! | findstr /b /c:"Name:" >nul
        if !errorlevel!==0 set "DNSA_SEENNAME=1"
    ) else if not defined DNSA_VERIFY (
        echo !DVL! | findstr /c:"Address" >nul
        if !errorlevel!==0 for /f "tokens=1,* delims=:" %%A in ("!DVL!") do set "DNSA_VERIFY=%%B"
    )
)
if defined DNSA_VERIFY set "DNSA_VERIFY=!DNSA_VERIFY: =!"
if defined DNSA_VERIFY echo !L_DNS_ASSIST_VERIFY_LABEL! !DNSA_VERIFY!
echo !L_DNS_ASSIST_DONE!
exit /b

:DNS_RESET_DHCP
echo.
call :DNS_DETECT_ADAPTER
if not defined DNSA_ADAPTER (
    netsh interface show interface
    echo.
    set "DNSA_ADAPTER="
    set /p "DNSA_ADAPTER=!L_DNS_DHCP_PROMPT! "
    if "!DNSA_ADAPTER!"=="" exit /b
)
netsh interface ip set dns name="!DNSA_ADAPTER!" dhcp
netsh interface ipv6 set dns name="!DNSA_ADAPTER!" dhcp >nul 2>&1
call :SET_SETTING DNS_MODE system
echo %C_GREEN%!L_DNS_DHCP_DONE!%C_RESET%
>> "%LOG_DIR%\app.log" echo [%date% %time%] DNS RESET dhcp adapter="!DNSA_ADAPTER!"
exit /b

:TOGGLE_DEBUG
call :LOAD_SETTINGS
if "!DEBUG!"=="1" (
    call :SET_SETTING DEBUG 0
    echo %L_DEBUG_TAG_OFF%
) else (
    call :SET_SETTING DEBUG 1
    echo %L_DEBUG_TAG_ON%
)
exit /b

rem ============================================================
rem  PROFIL alt menusu (ana menu [3])
rem  Profil degistir + profili dosyaya aktar/dosyadan al +
rem  GitHub Issue raporu. Alt islemler kendi pause'unu
rem  yapmadigi icin burada (parantezli blokta) pause verilir;
rem  CHANGE_PROFILE zaten kendi pause'unu yapiyor.
rem ============================================================
:PROFILE_MENU
cls
call :LOAD_SETTINGS
call :GET_DISPLAY_NAME "!CURRENT_PROFILE!" PMNAME
echo %C_CYAN%============================================================%C_RESET%
echo   %L_PMENU_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo   %L_LBL_PROFILE% : !CURRENT_PROFILE! (!PMNAME!)
echo.
echo   !L_PMENU_OPT_CHANGE!
echo   !L_PMENU_OPT_EXPORT!
echo   !L_PMENU_OPT_IMPORT!
echo   !L_PMENU_OPT_REPORT!
echo   %L_SVC_MENU_BACK%
echo.
set "PM="
set /p "PM=%L_PROMPT_CHOICE% "
if "%PM%"=="1" call :CHANGE_PROFILE
if "%PM%"=="2" (
    call :PROFILE_EXPORT
    pause
)
if "%PM%"=="3" (
    call :PROFILE_IMPORT
    pause
)
if "%PM%"=="4" (
    call :ISS_REPORT
    pause
)
exit /b

rem ============================================================
rem  FILE_DIALOG - Windows'un klasik "Dosya Ac" / "Farkli Kaydet"
rem  penceresi (PowerShell + System.Windows.Forms, tek satirlik
rem  komut, ayri script dosyasi YOK).
rem    %1 = OPEN veya SAVE     %2 = sonuc degiskeninin adi
rem  Cagirmadan once ayarlanir: ZT_DLG_TITLE, ZT_DLG_FILTER,
rem  (SAVE icin) ZT_DLG_FILE varsayilan ad, ZT_DLG_EXT uzanti.
rem  Cikti: %2 = secilen yol (Iptal edildiyse BOS)
rem         FD_FAILED = 1 ise pencere ACILAMADI (PowerShell yok /
rem         kisitli) - cagiran elle yol girisine dusmeli; 0 ise
rem         pencere acildi (iptal de olabilir).
rem  Baslik/filtre PowerShell'e ortam degiskeniyle gecer, boylece
rem  komut satirina tirnak/parantez iceren metin gomulmez.
rem ============================================================
:FILE_DIALOG
set "FD_FAILED=0"
set "FD_OUT="
set "%~2="
where powershell >nul 2>&1
if errorlevel 1 (
    set "FD_FAILED=1"
    exit /b
)
set "FD_CLASS=OpenFileDialog"
set "FD_EXTRA=$d.CheckFileExists = $true;"
if /I "%~1"=="SAVE" set "FD_CLASS=SaveFileDialog"
if /I "%~1"=="SAVE" set "FD_EXTRA=$d.FileName = $env:ZT_DLG_FILE; $d.DefaultExt = $env:ZT_DLG_EXT; $d.AddExtension = $true; $d.OverwritePrompt = $true; $d.InitialDirectory = [Environment]::GetFolderPath('Desktop');"
set "ZT_DLG_OUT=%TEMP%\zt_dialog_out.txt"
del "%ZT_DLG_OUT%" >nul 2>&1
start "" /wait /min powershell -NoProfile -STA -WindowStyle Hidden -Command "try { Add-Type -AssemblyName System.Windows.Forms; $f = New-Object System.Windows.Forms.Form; $f.TopMost = $true; $d = New-Object System.Windows.Forms.%FD_CLASS%; $d.Title = $env:ZT_DLG_TITLE; $d.Filter = $env:ZT_DLG_FILTER; %FD_EXTRA% if ($d.ShowDialog($f) -eq 'OK') { [System.IO.File]::WriteAllText($env:ZT_DLG_OUT, $d.FileName) } else { [System.IO.File]::WriteAllText($env:ZT_DLG_OUT, 'ZT_CANCEL') } } catch { [System.IO.File]::WriteAllText($env:ZT_DLG_OUT, 'ZT_ERR') }" >nul 2>&1
rem PowerShell AYRI ve gizli bir pencerede calisir (start /wait): bizim
rem konsola baglanmaz, boylece konsol fontu/kodlamasi bozulmaz. Sonucu
rem gecici dosyaya yazar. Dosya hic olusmadiysa PowerShell calismamis
rem demektir -> yedek (elle yol) akisina dus.
if not exist "%ZT_DLG_OUT%" (
    set "FD_FAILED=1"
    exit /b
)
for /f "usebackq delims=" %%P in (`type "%ZT_DLG_OUT%" 2^>nul`) do set "FD_OUT=%%P"
del "%ZT_DLG_OUT%" >nul 2>&1
if "!FD_OUT!"=="ZT_ERR" (
    set "FD_FAILED=1"
    set "FD_OUT="
)
if "!FD_OUT!"=="ZT_CANCEL" set "FD_OUT="
set "%~2=!FD_OUT!"
exit /b

rem ============================================================
rem  CLEAN_PATH - elle girilen/surukle-birak yolu temizler.
rem  Giris/cikis: CP_VAL  (sondaki bosluklari atar, tirnaklari
rem  kaldirir). Sadece pencere acilamayinca yedek yolda kullanilir.
rem ============================================================
:CLEAN_PATH
if not defined CP_VAL exit /b
:CLEAN_PATH_LOOP
if "!CP_VAL:~-1!"==" " (
    set "CP_VAL=!CP_VAL:~0,-1!"
    goto CLEAN_PATH_LOOP
)
set "CP_VAL=%CP_VAL:"=%"
exit /b

rem ============================================================
rem  PROFILI DISA AKTAR
rem  Secili profili, IMPORT'un okudugu formatta (CURRENT_PROFILE=)
rem  kullanicinin sectigi yere kaydeder. Ayni isimde dosya varsa
rem  Windows penceresi zaten "uzerine yazilsin mi" diye sorar;
rem  yedek (elle yol) akista bunu biz sorariz.
rem ============================================================
:PROFILE_EXPORT
cls
call :LOAD_SETTINGS
echo %C_CYAN%============================================================%C_RESET%
echo   %L_PEXPORT_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo !L_PEXPORT_INFO!
echo !L_PEXPORT_PROFILE_LABEL! !CURRENT_PROFILE!
echo.
set "ZT_DLG_TITLE=!L_PEXPORT_DIALOG_TITLE!"
set "ZT_DLG_FILTER=Zapret Turkey profile (*.conf)|*.conf|Text file (*.txt)|*.txt|All files (*.*)|*.*"
set "ZT_DLG_FILE=zapret-turkey-profile.conf"
set "ZT_DLG_EXT=conf"
call :FILE_DIALOG SAVE PEX_TARGET
if "!FD_FAILED!"=="1" (
    echo !L_PEXPORT_DIALOG_FAILED!
    set "PEX_TARGET="
    set /p "PEX_TARGET=!L_PEXPORT_PATH_PROMPT! "
    set "CP_VAL=!PEX_TARGET!"
    call :CLEAN_PATH
    set "PEX_TARGET=!CP_VAL!"
    if defined PEX_TARGET if exist "!PEX_TARGET!" (
        choice /c YN /n /m "!L_PEXPORT_OVERWRITE_PROMPT! "
        if errorlevel 2 set "PEX_TARGET="
    )
)
if not defined PEX_TARGET (
    echo !L_PEXPORT_CANCELLED!
    exit /b
)
> "%PEX_TARGET%" echo # Zapret Turkey profile file
>> "%PEX_TARGET%" echo CURRENT_PROFILE=!CURRENT_PROFILE!
findstr /b /c:"CURRENT_PROFILE=" "%PEX_TARGET%" >nul 2>&1
if errorlevel 1 (
    echo %C_RED%!L_PEXPORT_FAILED!%C_RESET%
    exit /b
)
echo %C_GREEN%!L_PEXPORT_DONE!%C_RESET% !PEX_TARGET!
exit /b

rem ============================================================
rem  PROFILI ICE AKTAR
rem  Windows "Dosya Ac" penceresiyle secilen dosyadan SADECE
rem  CURRENT_PROFILE okunur (hem dis aktarilan profil dosyasi
rem  hem de tam bir settings.conf calisir). DNS_MODE / DEBUG /
rem  LANG bilerek ice aktarilmaz: DNS_MODE gercek sistem DNS'i
rem  degil uygulamanin etiketidir ve baska birinin dosyasindan
rem  DNS'e dokunmak istemiyoruz. Profil adi sadece harf/rakam/_/-
rem  kabul eder ve profiles\ altinda gercekten var olmalidir.
rem ============================================================
:PROFILE_IMPORT
cls
call :LOAD_SETTINGS
echo %C_CYAN%============================================================%C_RESET%
echo   %L_IMPORT_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo !L_IMPORT_INFO!
echo.
set "ZT_DLG_TITLE=!L_IMPORT_DIALOG_TITLE!"
set "ZT_DLG_FILTER=Zapret Turkey profile (*.conf)|*.conf|Text file (*.txt)|*.txt|All files (*.*)|*.*"
call :FILE_DIALOG OPEN IMP_PATH
if "!FD_FAILED!"=="1" (
    echo !L_IMPORT_DIALOG_FAILED!
    set "IMP_PATH="
    set /p "IMP_PATH=!L_IMPORT_PROMPT! "
    set "CP_VAL=!IMP_PATH!"
    call :CLEAN_PATH
    set "IMP_PATH=!CP_VAL!"
)
if not defined IMP_PATH (
    echo !L_IMPORT_CANCELLED!
    exit /b
)
if not exist "!IMP_PATH!" (
    echo %C_RED%!L_IMPORT_NOT_FOUND!%C_RESET% !IMP_PATH!
    exit /b
)

set "IMP_PROF="
for /f "usebackq tokens=1,* delims==" %%A in (`type "%IMP_PATH%" 2^>nul`) do if /I "%%A"=="CURRENT_PROFILE" set "IMP_PROF=%%B"
if not defined IMP_PROF (
    echo %C_RED%!L_IMPORT_NO_PROFILE!%C_RESET%
    exit /b
)

set "IMP_BAD="
for /f "delims=abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-" %%X in ("!IMP_PROF!") do set "IMP_BAD=1"
if defined IMP_BAD (
    echo %C_RED%!L_IMPORT_BAD_PROFILE!%C_RESET% !IMP_PROF!
    exit /b
)
if not exist "%PROFILE_DIR%\!IMP_PROF!.conf" (
    echo %C_RED%!L_IMPORT_PROFILE_MISSING!%C_RESET% !IMP_PROF!
    exit /b
)

echo.
echo !L_IMPORT_CURRENT_LABEL! !CURRENT_PROFILE!
echo !L_IMPORT_NEW_LABEL! !IMP_PROF!
echo.
if /I "!IMP_PROF!"=="!CURRENT_PROFILE!" (
    echo !L_IMPORT_ALREADY!
    exit /b
)
choice /c YN /n /m "!L_IMPORT_CONFIRM! "
if errorlevel 2 (
    echo !L_IMPORT_ABORTED!
    exit /b
)

call :SET_SETTING CURRENT_PROFILE !IMP_PROF!
echo %C_GREEN%%L_CHANGE_PROFILE_DONE% !IMP_PROF!%C_RESET%

tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (
    choice /c YN /n /m "%L_CHANGE_PROFILE_RESTART_PROMPT% "
    if not errorlevel 2 call :START_ENGINE
)

sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (
    echo %C_YELLOW%%L_CHANGE_PROFILE_SERVICE_NOTE_1%%C_RESET%
    echo %C_YELLOW%%L_CHANGE_PROFILE_SERVICE_NOTE_2%%C_RESET%
)
exit /b

rem ============================================================
rem  GITHUB ISSUE RAPORU
rem  docs\ISS.md'deki Issue formatinda kopyalanabilir bir blok
rem  uretir: ekrana yazar, panoya kopyalar, istenirse kullanicinin
rem  sectigi dosyaya kaydeder (sabit dosya adi YOK). Alan adlari
rem  dil seciminden BAGIMSIZ, hep ISS.md ile ayni kalir.
rem  Sadece guvenilir sekilde bilinenler doldurulur: profil,
rem  IPv4/IPv6 durumu, DNS etiketi. Discord/Roblox/Steam yalniz
rem  winws calisiyorsa ve curl varsa GERCEK curl testiyle
rem  doldurulur; aksi halde bos birakilir. ISS adi, baglanti
rem  turu ve CGNAT kullaniciya birakilir (tahmin edilmez).
rem ============================================================
:ISS_REPORT
cls
call :LOAD_SETTINGS
echo %C_CYAN%============================================================%C_RESET%
echo   %L_REPORT_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo !L_REPORT_COLLECTING!

set "EXP_PROF=!CURRENT_PROFILE!"
if /I "!CURRENT_PROFILE!"=="stable" set "EXP_PROF=Stable"
if /I "!CURRENT_PROFILE!"=="compatibility" set "EXP_PROF=Compatibility"
if /I "!CURRENT_PROFILE!"=="strong" set "EXP_PROF=Strong"

rem IPv4/IPv6: ipconfig satirlarindan DEGERE bakilir (dilden bagimsiz).
rem IPv4: 169.254.x (APIPA) sayilmaz. IPv6: sadece global unicast
rem (2xxx/3xxx) sayilir; Teredo (2001:0:) ve 6to4 (2002:) sayilmaz.
set "EXP_V4=yok"
set "EXP_V6=yok"
for /f "usebackq delims=" %%L in (`ipconfig ^| findstr /c:"IPv4" /c:"IPv6"`) do (
    set "EXP_LN=%%L"
    set "EXP_VAL="
    for /f "tokens=1,* delims=:" %%A in ("!EXP_LN!") do set "EXP_VAL=%%B"
    set "EXP_VAL=!EXP_VAL: =!"
    if defined EXP_VAL (
        if not "!EXP_LN:IPv4=!"=="!EXP_LN!" (
            if not "!EXP_VAL:~0,8!"=="169.254." set "EXP_V4=var"
        ) else (
            set "EXP_G=0"
            if "!EXP_VAL:~0,1!"=="2" set "EXP_G=1"
            if "!EXP_VAL:~0,1!"=="3" set "EXP_G=1"
            if "!EXP_VAL:~0,7!"=="2001:0:" set "EXP_G=0"
            if "!EXP_VAL:~0,5!"=="2002:" set "EXP_G=0"
            if "!EXP_G!"=="1" set "EXP_V6=var"
        )
    )
)

set "EXP_ISS="
set "EXP_CONN=(FTTH / VDSL / ADSL / GPON / diger)"
set "EXP_CGNAT=(var/yok/bilinmiyor)"
set "EXP_DISCORD=(calisiyor/calismiyor)"
set "EXP_ROBLOX=(calisiyor/calismiyor)"
set "EXP_STEAM=(calisiyor/calismiyor)"
set "EXP_TESTED=0"
where curl >nul 2>&1
if not errorlevel 1 (
    tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
    if not errorlevel 1 set "EXP_TESTED=1"
)
if "!EXP_TESTED!"=="1" (
    echo !L_REPORT_TESTING!
    call :EXPORT_CURL discord.com EXP_DISCORD
    call :EXPORT_CURL www.roblox.com EXP_ROBLOX
    call :EXPORT_CURL store.steampowered.com EXP_STEAM
)

set "EXP_NOTES=DNS etiketi: !DNS_MODE!"
if "!EXP_TESTED!"=="1" set "EXP_NOTES=!EXP_NOTES! - Discord/Roblox/Steam curl testiyle otomatik dolduruldu"

echo.
if "!EXP_TESTED!"=="0" echo %C_YELLOW%!L_REPORT_NOT_TESTED!%C_RESET%
echo !L_REPORT_COPY_HINT!
echo ------------------------------------------------------------
call :EXPORT_BLOCK
echo ------------------------------------------------------------

rem panoya: once gecici dosyaya yaz, sonra clip ile oku (call :etiket
rem ifadesini dogrudan pipe'a baglamiyoruz)
set "RPT_TMP=%TEMP%\zt_report.txt"
call :EXPORT_BLOCK > "%RPT_TMP%"
clip < "%RPT_TMP%"
if errorlevel 1 (
    echo %C_YELLOW%!L_REPORT_COPY_FAILED!%C_RESET%
) else (
    echo !L_REPORT_COPIED!
)

echo.
choice /c YN /n /m "!L_REPORT_SAVE_PROMPT! "
if errorlevel 2 (
    del "%RPT_TMP%" >nul 2>&1
    exit /b
)
set "ZT_DLG_TITLE=!L_REPORT_DIALOG_TITLE!"
set "ZT_DLG_FILTER=Text file (*.txt)|*.txt|All files (*.*)|*.*"
set "ZT_DLG_FILE=zapret-turkey-report.txt"
set "ZT_DLG_EXT=txt"
call :FILE_DIALOG SAVE RPT_TARGET
if "!FD_FAILED!"=="1" (
    echo %C_YELLOW%!L_REPORT_DIALOG_FAILED!%C_RESET%
    del "%RPT_TMP%" >nul 2>&1
    exit /b
)
if defined RPT_TARGET (
    copy /Y "%RPT_TMP%" "%RPT_TARGET%" >nul
    if errorlevel 1 (
        echo %C_RED%!L_PEXPORT_FAILED!%C_RESET%
    ) else (
        echo !L_REPORT_SAVED! !RPT_TARGET!
    )
)
del "%RPT_TMP%" >nul 2>&1
exit /b

rem tek bir site icin curl testi. %1 = domain, %2 = sonuc degiskeni
:EXPORT_CURL
curl -s -o nul --max-time 6 "https://%~1"
if errorlevel 1 (set "%~2=calismiyor") else (set "%~2=calisiyor")
exit /b

rem ISS.md formatindaki blogu STDOUT'a yazar (ekran veya dosya)
:EXPORT_BLOCK
echo ISS                : !EXP_ISS!
echo Baglanti turu      : !EXP_CONN!
echo IPv4               : !EXP_V4!
echo IPv6               : !EXP_V6!
echo CGNAT              : !EXP_CGNAT!
echo Calisan profil     : !EXP_PROF!
echo Discord            : !EXP_DISCORD!
echo Roblox             : !EXP_ROBLOX!
echo Steam              : !EXP_STEAM!
echo Notlar             : !EXP_NOTES!
exit /b

rem ============================================================
rem  GUNLUKLER
rem ============================================================
:LOGS_MENU
cls
echo %C_CYAN%============================================================%C_RESET%
echo   %L_LOGS_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo   !L_LOGS_OPT_SHOW!
echo   %L_LOGS_OPT_OPEN_FOLDER%
echo   %L_LOGS_OPT_ERRORS%
echo   %L_LOGS_OPT_STDERR%
echo   %L_LOGS_BACK%
echo.
set "LG="
set /p "LG=%L_PROMPT_CHOICE% "
if "%LG%"=="1" (
    if exist "%LOG_DIR%\app.log" (type "%LOG_DIR%\app.log") else (echo %L_LOGS_NONE_YET%)
    pause
)
if "%LG%"=="2" start "" explorer "%LOG_DIR%"
if "%LG%"=="3" (
    if exist "%LOG_DIR%\app.log" (
        findstr /I "HATA ERROR FAILED" "%LOG_DIR%\app.log"
    ) else (
        echo %L_LOGS_NONE_YET%
    )
    pause
)
if "%LG%"=="4" (
    if exist "%LOG_DIR%\engine_stderr.log" (type "%LOG_DIR%\engine_stderr.log") else (echo %L_LOGS_STDERR_NONE_YET%)
    pause
)
exit /b

rem ============================================================
rem  ARACLAR alt menusu
rem ============================================================
:TOOLS_MENU
cls
echo %C_CYAN%============================================================%C_RESET%
echo   %L_TOOLS_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo   %L_TOOLS_OPT_SITELIST%
echo   %L_TOOLS_OPT_TESTSITE%
echo   %L_TOOLS_OPT_DEBUG%
echo   !L_TOOLS_OPT_VPNTEST!
echo   %L_SVC_MENU_BACK%
echo.
set "TL="
set /p "TL=%L_PROMPT_CHOICE% "
if "%TL%"=="1" call :SITE_LIST_MENU
if "%TL%"=="2" call :TEST_SITE
if "%TL%"=="3" call :DEBUG_PANEL
if "%TL%"=="4" call :VPN_TEST
exit /b

rem ============================================================
rem  SITE LISTESI - target-hosts.txt / exclude-hosts.txt icin
rem  ortak goster/ekle/sil duzenleyicisi.
rem ============================================================
:SITE_LIST_MENU
cls
echo %C_CYAN%============================================================%C_RESET%
echo   %L_TOOLS_OPT_SITELIST%
echo %C_CYAN%============================================================%C_RESET%
echo   %C_CYAN%[1]%C_RESET%  !L_SITELIST_TARGET_LABEL!
echo   %C_CYAN%[2]%C_RESET%  !L_SITELIST_EXCLUDE_LABEL!
echo   %L_SVC_MENU_BACK%
echo.
set "SM="
set /p "SM=%L_PROMPT_CHOICE% "
if "%SM%"=="1" call :EDIT_LIST "%PROFILE_DIR%\target-hosts.txt" "!L_SITELIST_TARGET_LABEL!"
if "%SM%"=="2" call :EDIT_LIST "%PROFILE_DIR%\exclude-hosts.txt" "!L_SITELIST_EXCLUDE_LABEL!"
exit /b

rem %1 = dosya yolu, %2 = ekranda gosterilecek baslik
:EDIT_LIST
set "EL_FILE=%~1"
set "EL_NAME=%~2"

:EDIT_LIST_LOOP
cls
echo %C_CYAN%============================================================%C_RESET%
echo   %EL_NAME%
echo %C_CYAN%============================================================%C_RESET%
echo.
echo %L_SITELIST_OPT_SHOW%
echo %L_SITELIST_OPT_ADD%
echo %L_SITELIST_OPT_REMOVE%
echo %L_SVC_MENU_BACK%
echo.
set "EM="
set /p "EM=%L_PROMPT_CHOICE% "
if "%EM%"=="1" call :EDIT_LIST_SHOW
if "%EM%"=="2" call :EDIT_LIST_ADD
if "%EM%"=="3" call :EDIT_LIST_REMOVE
if "%EM%"=="0" exit /b
goto EDIT_LIST_LOOP

:EDIT_LIST_SHOW
echo.
if exist "%EL_FILE%" (
    type "%EL_FILE%"
) else (
    echo !L_SITELIST_EMPTY!
)
echo.
pause
exit /b

:EDIT_LIST_ADD
set "NEWSITE="
set /p "NEWSITE=!L_SITELIST_ADD_PROMPT! "
if "%NEWSITE%"=="" (
    echo %L_TESTSITE_EMPTY%
    pause
    exit /b
)
set "NEWSITE=%NEWSITE:https://=%"
set "NEWSITE=%NEWSITE:http://=%"
for /f "tokens=1 delims=/" %%H in ("%NEWSITE%") do set "NEWSITE=%%H"

set "EL_DUP=0"
if exist "%EL_FILE%" (
    findstr /I /X /C:"%NEWSITE%" "%EL_FILE%" >nul 2>&1
    if !errorlevel!==0 set "EL_DUP=1"
)
if "%EL_DUP%"=="1" (
    echo !L_SITELIST_ADD_DUPLICATE! !NEWSITE!
    pause
    exit /b
)
>> "%EL_FILE%" echo %NEWSITE%
echo %L_SITELIST_ADD_DONE% %NEWSITE%
call :SITELIST_RESTART_IF_RUNNING
pause
exit /b

rem Silme artik tam site adi yazmak yerine, listelenen NUMARAYA gore
rem calisir - yazim hatasi/buyuk-kucuk harf uyusmazligi riski kalmaz.
rem NOT: dosyayi dogrudan FOR /F ile ACMAK yerine, zaten calistigi
rem dogrulanmis olan "type" komutunun CIKTISINI okuyoruz - bazi
rem ortamlarda FOR /F'in dosyayi dogrudan acma modu (usebackq)
rem sessizce hicbir satir dondurmeyebiliyor; type ^| for /f
rem TAMAMEN FARKLI bir mekanizma kullanir ve daha guvenilirdir.
:EDIT_LIST_REMOVE
if not exist "%EL_FILE%" (
    echo !L_SITELIST_EMPTY!
    pause
    exit /b
)
set "RM_COUNT=0"
for /f "delims=" %%L in ('type "%EL_FILE%" 2^>nul') do (
    set /a RM_COUNT+=1
    echo   [!RM_COUNT!] %%L
)
if "%RM_COUNT%"=="0" (
    echo !L_SITELIST_EMPTY!
    pause
    exit /b
)
echo.
set "DELNUM="
set /p "DELNUM=%L_SITELIST_REMOVE_PROMPT% "
if "%DELNUM%"=="" (
    echo %L_TESTSITE_EMPTY%
    pause
    exit /b
)

set "DELSITE="
set "RM_LN=0"
for /f "delims=" %%L in ('type "%EL_FILE%" 2^>nul') do (
    set /a RM_LN+=1
    if "!RM_LN!"=="%DELNUM%" set "DELSITE=%%L"
)
if not defined DELSITE (
    echo !L_SITELIST_REMOVE_INVALID! !DELNUM!
    pause
    exit /b
)

set "RM_LN=0"
> "%EL_FILE%.tmp" (
    for /f "delims=" %%L in ('type "%EL_FILE%" 2^>nul') do (
        set /a RM_LN+=1
        if not "!RM_LN!"=="%DELNUM%" echo %%L
    )
)
move /Y "%EL_FILE%.tmp" "%EL_FILE%" >nul
echo %L_SITELIST_REMOVE_DONE% %DELSITE%
call :SITELIST_RESTART_IF_RUNNING
pause
exit /b

rem Servis olarak kuruluysa SERVISI yeniden baslatir; degilse ve
rem winws normal (hizmetsiz) calisiyorsa, onu HIDDEN modda (gorev
rem cubugunda pencere gostermeden) yeniden baslatir. winws su an
rem calismiyorsa (servis kurulu olsa bile durmussa) hic sormaz -
rem zaten aktif bir sey yok, degisiklik bir sonraki baslatmada
rem otomatik gecerli olur.
:SITELIST_RESTART_IF_RUNNING
call :CHECK_SERVICE SL_SVCSTATE
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if not %errorlevel%==0 exit /b

choice /c YN /n /m "%L_SITELIST_RESTART_PROMPT% "
if errorlevel 2 exit /b

if "%SL_SVCSTATE%"=="INSTALLED" (
    sc stop "%SVCNAME%" >nul 2>&1
    timeout /t 1 >nul
    sc start "%SVCNAME%" >nul 2>&1
    if !errorlevel!==0 (
        echo %C_GREEN%%L_SITELIST_RESTART_DONE%%C_RESET%
    ) else (
        echo %C_RED%%L_START_FAILED%%C_RESET%
    )
) else (
    call :LOAD_SETTINGS
    call :ENGINE_START_CORE "!CURRENT_PROFILE!" HIDDEN
    if "!CORE_OK!"=="1" (
        echo %C_GREEN%%L_SITELIST_RESTART_DONE%%C_RESET%
    ) else (
        echo %C_RED%%L_START_FAILED%%C_RESET% ^(!CORE_REASON!^)
    )
)
exit /b


rem ============================================================
rem  BIR SITEYI TEST ET - kullanicinin verdigi tek bir domain'e
rem  Otomatik Test'teki ayni curl mantigiyla baglanti testi yapar.
rem ============================================================
:TEST_SITE
cls
echo %C_CYAN%============================================================%C_RESET%
echo   %L_TESTSITE_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo.
where curl >nul 2>&1
if not %errorlevel%==0 (
    echo %C_RED%%L_AUTOTEST_CURL_MISSING%%C_RESET%
    pause
    exit /b
)
set "SITE="
set /p "SITE=!L_TESTSITE_PROMPT! "
if "%SITE%"=="" (
    echo %L_TESTSITE_EMPTY%
    pause
    exit /b
)
rem on ek (http:// / https://) ve yol kismini (/...) temizle
set "SITE=%SITE:https://=%"
set "SITE=%SITE:http://=%"
for /f "tokens=1 delims=/" %%H in ("%SITE%") do set "SITE=%%H"

tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if not %errorlevel%==0 echo %C_YELLOW%%L_TESTSITE_NOT_RUNNING_WARN%%C_RESET%

echo.
echo !L_TESTSITE_TESTING! !SITE!
curl -s -o nul --max-time 6 "https://%SITE%"
if %errorlevel%==0 (
    echo %C_GREEN%!L_TESTSITE_PASS!%C_RESET%
) else (
    echo %C_RED%!L_TESTSITE_FAIL!%C_RESET%
)
echo.
pause
exit /b

rem ============================================================
rem  DEBUG MODE - anlik durum paneli
rem ============================================================
:DEBUG_PANEL
cls
call :LOAD_SETTINGS
echo %C_CYAN%============================================================%C_RESET%
echo   %L_DEBUG_TITLE%
echo %C_CYAN%============================================================%C_RESET%
echo %L_DEBUG_ROOT_LABEL% %ROOT%
echo %L_DEBUG_ENGINE_DIR_LABEL% %ENGINE_DIR%
echo %L_DEBUG_PROFILE_DIR_LABEL% %PROFILE_DIR%
echo %L_DEBUG_LOG_DIR_LABEL% %LOG_DIR%
echo.
echo %L_DEBUG_PROFILE_ID_LABEL% !CURRENT_PROFILE!
call :GET_DISPLAY_NAME !CURRENT_PROFILE! DBG_NAME
echo %L_DEBUG_PROFILE_NAME_LABEL% !DBG_NAME!
set "DBG_CONF=%PROFILE_DIR%\!CURRENT_PROFILE!.conf"
echo %L_DEBUG_PROFILE_FILE_LABEL% !DBG_CONF!
if exist "!DBG_CONF!" (echo !L_DEBUG_FILE_EXISTS!) else (echo !L_DEBUG_FILE_MISSING!)

set "DBG_ARGS="
set "DBG_PORT=443"
if exist "!DBG_CONF!" (
    for /f "usebackq tokens=1,* delims==" %%A in ("!DBG_CONF!") do (
        if "%%A"=="ARGS" set "DBG_ARGS=%%B"
        if "%%A"=="PORT_TCP" set "DBG_PORT=%%B"
    )
)
echo %L_DEBUG_PARSED_PORT_LABEL% !DBG_PORT!
echo %L_DEBUG_PARSED_ARGS_LABEL% !DBG_ARGS!
echo.
net session >nul 2>&1
if %errorlevel%==0 (echo %L_DEBUG_ADMIN_LABEL% %L_DEBUG_YES%) else (echo %L_DEBUG_ADMIN_LABEL% %L_DEBUG_NO%)
tasklist /FI "IMAGENAME eq winws.exe" 2>nul | find /I "winws.exe" >nul
if %errorlevel%==0 (echo %L_DEBUG_WINWS_STATUS_LABEL% %L_DEBUG_WINWS_RUNNING%) else (echo %L_DEBUG_WINWS_STATUS_LABEL% %L_DEBUG_WINWS_NOT_RUNNING%)
sc query "%SVCNAME%" >nul 2>&1
if %errorlevel%==0 (echo %L_DEBUG_SVC_STATUS_LABEL% %L_SVC_INSTALLED%) else (echo %L_DEBUG_SVC_STATUS_LABEL% %L_SVC_NOT_INSTALLED%)
echo.
echo %L_DEBUG_LAST_CALL_TITLE%
if defined CORE_CMDLINE (
    echo %L_DEBUG_CMDLINE_LABEL% !CORE_CMDLINE!
    echo %L_DEBUG_RESULT_LABEL% !CORE_REASON!
    if defined CORE_EXITCODE echo %L_DEBUG_EXITCODE_LABEL% !CORE_EXITCODE!
    if defined CORE_STDERR_TAIL echo %L_DEBUG_STDERR_LABEL% !CORE_STDERR_TAIL!
) else (
    echo %L_DEBUG_NO_CALL_YET%
)
echo.
echo %L_DEBUG_LOG_FILES_LABEL% %LOG_DIR%
echo %C_CYAN%============================================================%C_RESET%
pause
exit /b
