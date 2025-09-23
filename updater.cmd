@echo off
chcp 65001 >nul
REM --- Paramètres ---
SET PreviousExe="B525-SMSManager.exe"
SET NewExe="B525-Manager.exe"
SET UpdateExe="B525-Manager-Update.exe"

SET MAXWAIT=10   
SET /A COUNT=0

REM --- Vérifier que le nouveau fichier existe ---
IF NOT EXIST "%UpdateExe%" (
    echo [ERREUR] Fichier de mise à jour introuvable : "%UpdateExe%"
    pause
    exit /b 1
)


REM --- Attendre que l'ancien exe soit fermé ---
:Check
tasklist /FI "IMAGENAME eq %PreviousExe%" | find /I %PreviousExe% >nul
IF %ERRORLEVEL%==0 (
    IF %COUNT% GEQ %MAXWAIT% (
        echo [ERREUR] Le programme ne s'est pas fermé dans le delai imparti.
        pause
        exit /b 1
    )
    timeout /t 1 >nul
    SET /A COUNT+=1
    GOTO Check
)

REM --- Remplacer l'ancien exe par le nouveau ---
del /F /Q %PreviousExe%
del /F /Q "manage_sms.ps1"
move /Y %UpdateExe% %NewExe%

REM --- Relancer le programme ---
start "" %NewExe%
exit

