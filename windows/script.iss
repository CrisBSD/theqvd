[Setup]
; NOTE: The value of AppId uniquely identifies this application.
; Do not use the same AppId value in installers for other applications.
; (To generate a new GUID, click Tools | Generate GUID inside the IDE.)
AppId={{DD625C30-A6B1-4C48-A3C2-19B39771028F}
AppName=QVD Client
AppVerName=QVD Client 3.1.0-0
AppVersion=3.1.0-0
AppPublisher=QindelGroup
AppPublisherURL=http://theqvd.com/
AppSupportURL=http://theqvd.com/
AppUpdatesURL=http://theqvd.com/
DefaultDirName={pf}\QVD
DisableDirPage=yes
DefaultGroupName=QVD Client
DisableProgramGroupPage=yes
OutputBaseFilename=qvd-client-setup-3.1.0-RC7
Compression=lzma
SolidCompression=yes
SetupIconFile=installer\pixmaps\qvd.ico

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "installer\NX\*"; DestDir: "{app}\NX"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "installer\pulseaudio\*"; DestDir: "{app}\pulseaudio"; Flags: ignoreversion recursesubdirs createallsubdirs
;Source: "installer\system32\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "installer\Xming\*"; DestDir: "{app}\Xming"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "installer\pixmaps\*"; DestDir: "{app}\pixmaps"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "installer\qvd-client.exe"; DestDir: "{app}"; Flags: ignoreversion
; Source: "c:\Strawberry\perl\bin\libstdc++-6.dll"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\QVD Client"; Filename: "{app}\qvd-client.exe"; WorkingDir: "{app}"
Name: "{commondesktop}\QVD Client"; Filename: "{app}\qvd-client.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
; Make LanmanServer accept 127.0.0.1 as its netbios name 
; REQUIRED for printing to work on Windows 7
Root: HKLM; Subkey: "System\CurrentControlSet\Services\LanmanServer\Parameters"; ValueType: string; ValueName: "OptionalNames"; ValueData: "127.0.0.1"; Flags: preservestringtype
