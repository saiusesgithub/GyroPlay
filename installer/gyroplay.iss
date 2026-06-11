#define AppName "GyroPlay"
#define AppVersion "0.1.0"
#define Publisher "GyroPlay"
#define AppExeName "GyroPlay.Desktop.exe"
#define BuildDir "build"

[Setup]
AppId={{8B45D1E4-2CB7-4B6D-A3F9-4E2D40A7F7CF}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#Publisher}
DefaultDirName={autopf}\GyroPlay
DefaultGroupName=GyroPlay
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=GyroPlaySetup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
UninstallDisplayIcon={app}\{#AppExeName}
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\desktop\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\engine\python\dist\GyroPlay.Engine.exe"; DestDir: "{app}\engine"; DestName: "GyroPlay.Engine.exe"; Flags: ignoreversion
Source: "dependencies\ViGEmBus_1.22.0_x64_x86_arm64.exe"; DestDir: "{app}\dependencies"; Flags: ignoreversion
Source: "..\docs\troubleshooting.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "dependencies\ViGEmBus_1.22.0_x64_x86_arm64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; AfterInstall: InstallViGEmBusIfNeeded

[Icons]
Name: "{group}\GyroPlay"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\GyroPlay"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""GyroPlay UDP 5005"" dir=in action=allow protocol=UDP localport=5005 profile=any"; StatusMsg: "Adding Windows Firewall rule..."; Flags: runhidden waituntilterminated
Filename: "{app}\{#AppExeName}"; Description: "Launch GyroPlay"; Flags: nowait postinstall skipifsilent

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""GyroPlay UDP 5005"""; Flags: runhidden waituntilterminated

[Code]
function IsViGEmBusInstalled: Boolean;
begin
  Result :=
    RegKeyExists(HKLM, 'SYSTEM\CurrentControlSet\Services\ViGEmBus') or
    RegKeyExists(HKLM64, 'SYSTEM\CurrentControlSet\Services\ViGEmBus') or
    RegKeyExists(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ViGEmBus') or
    RegKeyExists(HKLM64, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\ViGEmBus');
end;

procedure InstallViGEmBusIfNeeded;
var
  ResultCode: Integer;
begin
  if IsViGEmBusInstalled then
  begin
    Exit;
  end;

  WizardForm.StatusLabel.Caption := 'Installing ViGEmBus driver...';

  if not Exec(ExpandConstant('{tmp}\ViGEmBus_1.22.0_x64_x86_arm64.exe'), '/quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    MsgBox('ViGEmBus driver setup could not be started. GyroPlay requires ViGEmBus for virtual Xbox controller support.', mbError, MB_OK);
    Abort;
  end;

  if ResultCode <> 0 then
  begin
    MsgBox('ViGEmBus driver setup failed with exit code ' + IntToStr(ResultCode) + '. GyroPlay requires ViGEmBus for virtual Xbox controller support.', mbError, MB_OK);
    Abort;
  end;

  if not IsViGEmBusInstalled then
  begin
    MsgBox('ViGEmBus driver setup finished, but the ViGEmBus service was not detected. Installation will stop.', mbError, MB_OK);
    Abort;
  end;
end;
