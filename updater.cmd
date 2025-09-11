@echo off
REM --- Paramètres ---
SET LocalExe="B525-SMSManager.exe"
SET NewExe="B525-SMSManager-Update.exe"

REM --- Attendre que l'ancien exe soit fermé ---
:Check
tasklist /FI "IMAGENAME eq %LocalExe%" | find /I %LocalExe% >nul
IF %ERRORLEVEL%==0 (
    timeout /t 1 >nul
    GOTO Check
)

REM --- Remplacer l'ancien exe par le nouveau ---
move /Y %NewExe% %LocalExe%

REM --- Relancer le programme ---
start "" %LocalExe%
exit

