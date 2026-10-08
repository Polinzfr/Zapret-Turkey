@echo off
rem ============================================================
rem  lang-load.bat - Zapret Turkey dil yukleyici
rem
rem  ONEMLI: bu dosyada setlocal KULLANILMAZ. Amac, yukledigi
rem  L_* degiskenlerinin ve UI_LANG'in cagiran script'in ortaminda
rem  KALICI kalmasidir (call ile cagrildiginda ortam paylasilir).
rem  Bu yuzden bu dosya icinde de !gecikmeli genisletme! yerine
rem  hep %normal% genisletme kullanilir - cagiranin delayed
rem  expansion ayari acik ya da kapali olsa da calismasi icin.
rem
rem  Kullanim (baska bir .bat'in en basinda):
rem    call "%ROOT%scripts\lang-load.bat"
rem  ROOT ve CONFIG_FILE zaten taniml iysa onlar kullanilir; degilse
rem  bu dosya "scripts\" klasorune gore kendi hesaplar (bagimsiz
rem  calistirilan scriptler icin guvenlik agi).
rem ============================================================

if not defined ROOT set "ROOT=%~dp0..\"
set "LANG_DIR=%ROOT%lang"
if not defined CONFIG_FILE set "CONFIG_FILE=%ROOT%config\settings.conf"

rem ---- 1) once varsayilan (English) dosyayi yukle. Boylece bir
rem         anahtar herhangi bir dilde eksik kalirsa ekran BOS
rem         degil, anlasilir Ingilizce metinle dolar. ----------
call :LOAD_LANG_FILE "%LANG_DIR%\en.lang"

rem ---- 2) settings.conf'tan LANG= degerini oku ----------------
set "UI_LANG="
if exist "%CONFIG_FILE%" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
        if /I "%%A"=="LANG" set "UI_LANG=%%B"
    )
)

rem ---- 3) SWITCH parametresiyle cagrildiysa (Ayarlar - Dili
rem         degistir) veya LANG hic ayarlanmamissa (ilk calistirma)
rem         -> dil sec ----------------------------------------------
if /I "%~1"=="SWITCH" set "UI_LANG="
if not defined UI_LANG call :FIRST_RUN_LANG_PROMPT

rem ---- 4) secilen dil Turkce ise tr.lang ile USTUNE yaz --------
if /I "%UI_LANG%"=="tr" call :LOAD_LANG_FILE "%LANG_DIR%\tr.lang"

goto :EOF

rem ============================================================
rem  YARDIMCI: bir .lang dosyasini L_ANAHTAR degiskenlerine yukler
rem  %1 = tirnak icinde dosya yolu
rem ============================================================
:LOAD_LANG_FILE
if not exist %1 goto :EOF
for /f "usebackq eol=# tokens=1,* delims==" %%A in (%1) do (
    if not "%%A"=="" set "L_%%A=%%B"
)
goto :EOF

rem ============================================================
rem  ILK CALISTIRMA: dil secimi
rem  Not: bu asamada L_LANG_SELECT_* degerleri zaten en.lang'dan
rem  yuklu durumda (adim 1), o yuzden asagidaki metinler her zaman
rem  gosterilebilir - UI_LANG henuz belirlenmemis olsa bile.
rem ============================================================
:FIRST_RUN_LANG_PROMPT
cls
echo %L_LANG_SELECT_TITLE%
echo.
echo   %L_LANG_SELECT_OPT_TR%
echo   %L_LANG_SELECT_OPT_EN%
echo.
set /p "LSEL=%L_LANG_SELECT_PROMPT% "
if "%LSEL%"=="1" (
    set "UI_LANG=tr"
) else if "%LSEL%"=="2" (
    set "UI_LANG=en"
) else (
    echo %L_LANG_SELECT_INVALID%
    pause >nul
    goto FIRST_RUN_LANG_PROMPT
)
call :SAVE_LANG_SETTING
goto :EOF

rem ============================================================
rem  YARDIMCI: LANG= degerini settings.conf'a yazar - diger
rem  ayarlari (CURRENT_PROFILE, DNS_MODE, DEBUG) OLDUGU GIBI KORUR.
rem  ZapretTurkey.bat:SET_SETTING de ayni sekilde LANG satirini
rem  korumak zorunda - o rutin ayri bir adimda guncellenecek.
rem ============================================================
:SAVE_LANG_SETTING
if not exist "%ROOT%config" mkdir "%ROOT%config" >nul 2>&1

if not exist "%CONFIG_FILE%" (
    > "%CONFIG_FILE%" echo CURRENT_PROFILE=stable
    >> "%CONFIG_FILE%" echo DNS_MODE=system
    >> "%CONFIG_FILE%" echo DEBUG=0
    >> "%CONFIG_FILE%" echo LANG=%UI_LANG%
    goto :EOF
)

set "_LL_CP=stable"
set "_LL_DM=system"
set "_LL_DB=0"
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%CONFIG_FILE%") do (
    if /I "%%A"=="CURRENT_PROFILE" set "_LL_CP=%%B"
    if /I "%%A"=="DNS_MODE" set "_LL_DM=%%B"
    if /I "%%A"=="DEBUG" set "_LL_DB=%%B"
)
> "%CONFIG_FILE%" echo CURRENT_PROFILE=%_LL_CP%
>> "%CONFIG_FILE%" echo DNS_MODE=%_LL_DM%
>> "%CONFIG_FILE%" echo DEBUG=%_LL_DB%
>> "%CONFIG_FILE%" echo LANG=%UI_LANG%
set "_LL_CP="
set "_LL_DM="
set "_LL_DB="
goto :EOF
