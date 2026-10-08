@echo off
setlocal EnableExtensions
set "SVCNAME=ZapretTurkey"

call "%~dp0lang-load.bat"

echo ============================================================
echo   %L_SVC_UNINSTALL_TITLE%
echo ============================================================

net session >nul 2>&1
if %errorlevel% NEQ 0 (
    echo %L_SVC_ADMIN_REQUIRED%
    echo %L_SVC_ADMIN_HINT%
    pause
    exit /b 1
)

sc query "%SVCNAME%" >nul 2>&1
if not %errorlevel%==0 (
    echo %L_SVC_NOT_INSTALLED_MSG%
    pause
    exit /b 0
)

sc stop "%SVCNAME%" >nul 2>&1
sc delete "%SVCNAME%"
if %errorlevel%==0 (
    echo %L_SVC_UNINSTALLED_OK% %SVCNAME%
) else (
    echo %L_SVC_ERR_UNINSTALL_FAILED%
)

echo.
echo %L_SVC_UNINSTALL_NOTE_1A%%SVCNAME%%L_SVC_UNINSTALL_NOTE_1B%
echo %L_SVC_UNINSTALL_NOTE_2%
echo %L_SVC_UNINSTALL_NOTE_3%
echo %L_SVC_UNINSTALL_NOTE_4%
pause
exit /b 0
