#define AppName "GyroPlay"
#ifndef AppVersion
#define AppVersion "0.1.0"
#endif
#define Publisher "GyroPlay"
#define ProjectUrl "https://github.com/GyroPlay/GyroPlay"
#define AppExeName "GyroPlay.Desktop.exe"
#define EngineExeName "GyroPlay.Engine.exe"
#define FirewallRuleName "GyroPlay UDP 5005"
#define DriverInstallerName "ViGEmBus_1.22.0_x64_x86_arm64.exe"
#define BuildDir "build"
#define AppGuid "{8B45D1E4-2CB7-4B6D-A3F9-4E2D40A7F7CF}"

[Setup]
AppId={{8B45D1E4-2CB7-4B6D-A3F9-4E2D40A7F7CF}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#Publisher}
AppPublisherURL={#ProjectUrl}
AppSupportURL={#ProjectUrl}
AppUpdatesURL={#ProjectUrl}
VersionInfoVersion={#AppVersion}
VersionInfoCompany={#Publisher}
VersionInfoDescription=GyroPlay Setup
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#AppVersion}
SetupIconFile=assets\GyroPlay.ico
WizardImageFile=assets\WizardImage.png
WizardSmallImageFile=assets\WizardSmallImage.png
DefaultDirName={autopf}\GyroPlay
DefaultGroupName=GyroPlay
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=GyroPlaySetup-{#AppVersion}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
WizardSizePercent=110
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
CloseApplications=yes
RestartApplications=no
UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\Assets\GyroPlay.ico
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Welcome to the [name] Setup Wizard
WelcomeLabel2=GyroPlay turns your Android phone into a wireless controller for Windows racing games.%n%nSetup installs the desktop control panel, the packaged controller engine, a virtual controller driver if needed, and a local-network firewall rule for UDP port 5005.%n%nNo account or cloud service is required.
FinishedHeadingLabel=GyroPlay setup is complete

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "openguide"; Description: "Open the getting-started guide"; GroupDescription: "After setup:"; Flags: unchecked

[Files]
Source: "{#BuildDir}\desktop\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs restartreplace uninsrestartdelete
Source: "..\engine\python\dist\{#EngineExeName}"; DestDir: "{app}\engine"; DestName: "{#EngineExeName}"; Flags: ignoreversion restartreplace uninsrestartdelete
Source: "dependencies\{#DriverInstallerName}"; DestDir: "{app}\dependencies"; Flags: ignoreversion
Source: "..\docs\troubleshooting.md"; DestDir: "{app}\docs"; Flags: ignoreversion
Source: "dependencies\{#DriverInstallerName}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\GyroPlay"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\Assets\GyroPlay.ico"
Name: "{autodesktop}\GyroPlay"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; IconFilename: "{app}\Assets\GyroPlay.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "Launch GyroPlay"; Flags: nowait postinstall skipifsilent; Check: CanLaunchAfterSetup
Filename: "{cmd}"; Parameters: "/C start """" ""{app}\docs\troubleshooting.md"""; Description: "Open the getting-started guide"; Flags: postinstall skipifsilent runhidden; Tasks: openguide

[UninstallRun]
Filename: "{sys}\taskkill.exe"; Parameters: "/IM {#EngineExeName} /F"; Flags: runhidden waituntilterminated
Filename: "{sys}\taskkill.exe"; Parameters: "/IM {#AppExeName} /F"; Flags: runhidden waituntilterminated
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRuleName}"""; Flags: runhidden waituntilterminated

[Code]
var
  DependencyPage: TWizardPage;
  DriverStatusLabel: TNewStaticText;
  FirewallStatusLabel: TNewStaticText;
  DataNoteLabel: TNewStaticText;
  RestartRequired: Boolean;
  RemoveUserData: Boolean;
  LastDriverStatus: String;
  LastFirewallStatus: String;
  SetupLogFile: String;

function RunHidden(FileName: String; Parameters: String; var ResultCode: Integer): Boolean;
begin
  Log('Running: ' + FileName + ' ' + Parameters);
  Result := Exec(FileName, Parameters, '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
  Log('Exit code: ' + IntToStr(ResultCode));
end;

procedure AppendSetupLog(Message: String);
begin
  if SetupLogFile = '' then
  begin
    SetupLogFile := ExpandConstant('{localappdata}\GyroPlay\Logs\setup.log');
    ForceDirectories(ExtractFileDir(SetupLogFile));
  end;

  SaveStringToFile(SetupLogFile, GetDateTimeString('yyyy-mm-dd hh:nn:ss', '-', ':') + ' ' + Message + #13#10, True);
  Log(Message);
end;

function IsProcessRunning(ImageName: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := False;
  if RunHidden(ExpandConstant('{cmd}'), '/C tasklist /FI "IMAGENAME eq ' + ImageName + '" | find /I "' + ImageName + '" >NUL', ResultCode) then
  begin
    Result := ResultCode = 0;
  end;
end;

function DriverServiceExists: Boolean;
var
  ResultCode: Integer;
begin
  Result := RunHidden(ExpandConstant('{sys}\sc.exe'), 'query ViGEmBus', ResultCode) and (ResultCode = 0);
end;

function DriverServiceRunning: Boolean;
var
  ResultCode: Integer;
begin
  Result := RunHidden(ExpandConstant('{cmd}'), '/C sc query ViGEmBus | find "RUNNING" >NUL', ResultCode) and (ResultCode = 0);
end;

function GetDriverStatus: String;
begin
  if DriverServiceRunning then
  begin
    Result := 'Installed and running';
  end
  else if DriverServiceExists then
  begin
    Result := 'Installed but unavailable';
  end
  else
  begin
    Result := 'Missing';
  end;
end;

function FirewallRuleExists: Boolean;
var
  ResultCode: Integer;
begin
  Result := RunHidden(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall show rule name="{#FirewallRuleName}"', ResultCode) and (ResultCode = 0);
end;

function FirewallRuleHas(Text: String): Boolean;
var
  ResultCode: Integer;
begin
  Result := RunHidden(ExpandConstant('{cmd}'), '/C netsh advfirewall firewall show rule name="{#FirewallRuleName}" | findstr /I /C:"' + Text + '" >NUL', ResultCode) and (ResultCode = 0);
end;

function FirewallRuleHealthy: Boolean;
begin
  Result :=
    FirewallRuleExists and
    FirewallRuleHas('Enabled:') and
    (not FirewallRuleHas('Enabled:                              No')) and
    FirewallRuleHas('Direction:                            In') and
    FirewallRuleHas('Protocol:                             UDP') and
    FirewallRuleHas('LocalPort:                            5005');
end;

function GetFirewallStatus: String;
begin
  if FirewallRuleHealthy then
  begin
    Result := 'Configured';
  end
  else if FirewallRuleExists then
  begin
    Result := 'Disabled or incorrect';
  end
  else
  begin
    Result := 'Missing';
  end;
end;

procedure RefreshDependencyPage;
begin
  LastDriverStatus := GetDriverStatus;
  LastFirewallStatus := GetFirewallStatus;

  if DriverStatusLabel <> nil then
  begin
    DriverStatusLabel.Caption := 'Virtual controller driver: ' + LastDriverStatus;
  end;

  if FirewallStatusLabel <> nil then
  begin
    FirewallStatusLabel.Caption := 'Local network firewall rule: ' + LastFirewallStatus;
  end;
end;

function RepairFirewallRule: Boolean;
var
  ResultCode: Integer;
begin
  AppendSetupLog('Checking GyroPlay firewall rule.');

  if FirewallRuleHealthy then
  begin
    AppendSetupLog('Firewall rule is already configured.');
    Result := True;
    Exit;
  end;

  if FirewallRuleExists then
  begin
    AppendSetupLog('Removing incorrect GyroPlay firewall rule before recreating it.');
    RunHidden(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall delete rule name="{#FirewallRuleName}"', ResultCode);
  end;

  if not RunHidden(ExpandConstant('{sys}\netsh.exe'), 'advfirewall firewall add rule name="{#FirewallRuleName}" dir=in action=allow protocol=UDP localport=5005 profile=any enable=yes', ResultCode) then
  begin
    AppendSetupLog('Firewall rule command could not be started.');
    Result := False;
    Exit;
  end;

  if ResultCode <> 0 then
  begin
    AppendSetupLog('Firewall rule setup failed with exit code ' + IntToStr(ResultCode) + '.');
    Result := False;
    Exit;
  end;

  Result := FirewallRuleHealthy;
  if Result then
  begin
    AppendSetupLog('Firewall rule configured successfully.');
  end
  else
  begin
    AppendSetupLog('Firewall rule setup finished, but verification failed.');
  end;
end;

function InstallOrRepairDriver: Boolean;
var
  ResultCode: Integer;
  DriverInstaller: String;
  Status: String;
begin
  Status := GetDriverStatus;
  LastDriverStatus := Status;

  if Status = 'Installed and running' then
  begin
    AppendSetupLog('ViGEmBus driver is already installed and running.');
    Result := True;
    Exit;
  end;

  DriverInstaller := ExpandConstant('{tmp}\{#DriverInstallerName}');
  if not FileExists(DriverInstaller) then
  begin
    AppendSetupLog('Missing ViGEmBus installer payload: ' + DriverInstaller);
    MsgBox('The virtual controller driver payload is missing from this setup package. Please download a fresh GyroPlay installer.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if Status = 'Installed but unavailable' then
  begin
    if MsgBox('The virtual controller driver is installed but is not available. Setup can repair it now. Continue?', mbConfirmation, MB_YESNO) <> IDYES then
    begin
      AppendSetupLog('User cancelled ViGEmBus repair.');
      Result := False;
      Exit;
    end;
    WizardForm.StatusLabel.Caption := 'Repairing virtual controller driver...';
    AppendSetupLog('Repairing ViGEmBus driver.');
  end
  else
  begin
    WizardForm.StatusLabel.Caption := 'Installing virtual controller driver...';
    AppendSetupLog('Installing ViGEmBus driver.');
  end;

  if not RunHidden(DriverInstaller, '/quiet /norestart', ResultCode) then
  begin
    AppendSetupLog('ViGEmBus installer could not be started.');
    MsgBox('The virtual controller driver setup could not be started. Try running the GyroPlay installer again as administrator.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  if ResultCode = 3010 then
  begin
    RestartRequired := True;
    AppendSetupLog('ViGEmBus setup completed and requested a Windows restart.');
  end
  else if ResultCode = 1602 then
  begin
    AppendSetupLog('ViGEmBus setup was cancelled by the user.');
    MsgBox('Driver setup was cancelled. GyroPlay needs the virtual controller driver before it can control games.', mbError, MB_OK);
    Result := False;
    Exit;
  end
  else if ResultCode <> 0 then
  begin
    AppendSetupLog('ViGEmBus setup failed with exit code ' + IntToStr(ResultCode) + '.');
    MsgBox('The virtual controller driver setup failed. Restart Windows and run the GyroPlay installer again. Technical setup notes are saved to:' + #13#10 + SetupLogFile, mbError, MB_OK);
    Result := False;
    Exit;
  end
  else
  begin
    AppendSetupLog('ViGEmBus setup completed successfully.');
  end;

  Result := DriverServiceExists;
  if not Result then
  begin
    AppendSetupLog('ViGEmBus service was not detected after setup.');
    MsgBox('Driver setup finished, but Windows did not report the virtual controller driver as installed. Restart Windows and run Repair Setup from GyroPlay Diagnostics if needed.', mbError, MB_OK);
  end;
end;

function CanLaunchAfterSetup: Boolean;
begin
  Result := (not RestartRequired) and FileExists(ExpandConstant('{app}\{#AppExeName}'));
end;

function NeedRestart: Boolean;
begin
  Result := RestartRequired;
end;

function PopVersionPart(var Version: String): Integer;
var
  DotPosition: Integer;
  Part: String;
begin
  DotPosition := Pos('.', Version);
  if DotPosition = 0 then
  begin
    Part := Version;
    Version := '';
  end
  else
  begin
    Part := Copy(Version, 1, DotPosition - 1);
    Delete(Version, 1, DotPosition);
  end;

  Result := StrToIntDef(Part, 0);
end;

function CompareVersionStrings(LeftVersion: String; RightVersion: String): Integer;
var
  Index: Integer;
  LeftPart: Integer;
  RightPart: Integer;
begin
  Result := 0;

  for Index := 1 to 4 do
  begin
    LeftPart := PopVersionPart(LeftVersion);
    RightPart := PopVersionPart(RightVersion);

    if LeftPart > RightPart then
    begin
      Result := 1;
      Exit;
    end;

    if LeftPart < RightPart then
    begin
      Result := -1;
      Exit;
    end;
  end;
end;

function GetInstalledVersion: String;
var
  Version: String;
begin
  Version := '';
  RegQueryStringValue(HKLM64, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#AppGuid}_is1', 'DisplayVersion', Version);
  Result := Version;
end;

function InitializeSetup: Boolean;
var
  ExistingVersion: String;
begin
  Result := True;
  SetupLogFile := ExpandConstant('{localappdata}\GyroPlay\Logs\setup.log');
  ForceDirectories(ExtractFileDir(SetupLogFile));
  AppendSetupLog('Starting GyroPlay Setup {#AppVersion}.');

  if not IsAdminLoggedOn then
  begin
    MsgBox('GyroPlay setup needs administrator permission because it installs a virtual controller driver and configures a local firewall rule.', mbError, MB_OK);
    Result := False;
    Exit;
  end;

  ExistingVersion := GetInstalledVersion;
  if ExistingVersion <> '' then
  begin
    AppendSetupLog('Existing GyroPlay version detected: ' + ExistingVersion);
    if CompareVersionStrings(ExistingVersion, '{#AppVersion}') > 0 then
    begin
      if MsgBox('A newer version of GyroPlay (' + ExistingVersion + ') appears to be installed. Installing {#AppVersion} may downgrade files. Continue?', mbConfirmation, MB_YESNO) <> IDYES then
      begin
        Result := False;
        Exit;
      end;
    end;
  end;
end;

procedure InitializeWizard;
begin
  DependencyPage := CreateCustomPage(wpSelectTasks, 'Dependency and setup status', 'GyroPlay checks the Windows components it needs before installation.');

  DriverStatusLabel := TNewStaticText.Create(DependencyPage);
  DriverStatusLabel.Parent := DependencyPage.Surface;
  DriverStatusLabel.Left := 0;
  DriverStatusLabel.Top := ScaleY(8);
  DriverStatusLabel.Width := DependencyPage.SurfaceWidth;
  DriverStatusLabel.Caption := 'Virtual controller driver: checking...';

  FirewallStatusLabel := TNewStaticText.Create(DependencyPage);
  FirewallStatusLabel.Parent := DependencyPage.Surface;
  FirewallStatusLabel.Left := 0;
  FirewallStatusLabel.Top := ScaleY(36);
  FirewallStatusLabel.Width := DependencyPage.SurfaceWidth;
  FirewallStatusLabel.Caption := 'Local network firewall rule: checking...';

  DataNoteLabel := TNewStaticText.Create(DependencyPage);
  DataNoteLabel.Parent := DependencyPage.Surface;
  DataNoteLabel.Left := 0;
  DataNoteLabel.Top := ScaleY(76);
  DataNoteLabel.Width := DependencyPage.SurfaceWidth;
  DataNoteLabel.Height := ScaleY(80);
  DataNoteLabel.WordWrap := True;
  DataNoteLabel.Caption := 'Setup preserves your GyroPlay settings, logs, pairing state, and controller profiles during install, upgrade, reinstall, and repair. The virtual controller driver is only installed or repaired when needed.';

  RefreshDependencyPage;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if CurPageID = DependencyPage.ID then
  begin
    RefreshDependencyPage;
  end;

  if CurPageID = wpFinished then
  begin
    RefreshDependencyPage;
    if RestartRequired then
    begin
      WizardForm.FinishedLabel.Caption := 'GyroPlay was installed, but Windows should be restarted before launching it.' + #13#10#13#10 +
        'Driver status: ' + LastDriverStatus + #13#10 +
        'Firewall status: ' + LastFirewallStatus + #13#10 +
        'Setup notes: ' + SetupLogFile;
    end
    else
    begin
      WizardForm.FinishedLabel.Caption := 'GyroPlay installed successfully.' + #13#10#13#10 +
        'Driver status: ' + LastDriverStatus + #13#10 +
        'Firewall status: ' + LastFirewallStatus + #13#10 +
        'Setup notes: ' + SetupLogFile;
    end;
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  Result := '';
  NeedsRestart := False;

  while IsProcessRunning('{#AppExeName}') or IsProcessRunning('{#EngineExeName}') do
  begin
    if MsgBox('GyroPlay is currently running. Close GyroPlay and its controller engine, then choose Retry to continue setup.', mbError, MB_RETRYCANCEL) <> IDRETRY then
    begin
      Result := 'Setup cannot safely replace GyroPlay while it is running.';
      Exit;
    end;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    if not InstallOrRepairDriver then
    begin
      Abort;
    end;

    if not RepairFirewallRule then
    begin
      MsgBox('GyroPlay was installed, but setup could not configure the local-network firewall rule for UDP port 5005. Open GyroPlay Diagnostics and use Repair Firewall, or allow UDP 5005 manually.', mbError, MB_OK);
      Abort;
    end;

    RefreshDependencyPage;
  end;
end;

function InitializeUninstall: Boolean;
begin
  Result := True;
  RemoveUserData := False;

  MsgBox('Uninstall will remove GyroPlay application files, shortcuts, and the GyroPlay-owned firewall rule.' + #13#10#13#10 +
    'The ViGEmBus driver will not be removed because other applications may use it.', mbInformation, MB_OK);

  if MsgBox('Do you also want to remove GyroPlay user data from LocalAppData? This includes settings, logs, pairing state, and local profiles.' + #13#10#13#10 +
    'Choose No to keep your preferences for a future install.', mbConfirmation, MB_YESNO) = IDYES then
  begin
    RemoveUserData := True;
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ResultCode: Integer;
  UserDataPath: String;
begin
  if CurUninstallStep = usUninstall then
  begin
    RunHidden(ExpandConstant('{sys}\taskkill.exe'), '/IM {#EngineExeName} /F', ResultCode);
    RunHidden(ExpandConstant('{sys}\taskkill.exe'), '/IM {#AppExeName} /F', ResultCode);
  end;

  if CurUninstallStep = usPostUninstall then
  begin
    if RemoveUserData then
    begin
      UserDataPath := ExpandConstant('{localappdata}\GyroPlay');
      AppendSetupLog('Removing GyroPlay user data: ' + UserDataPath);
      DelTree(UserDataPath, True, True, True);
    end;
  end;
end;
