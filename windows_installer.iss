[Setup]
AppId={{C6D27301-B136-4190-8E1E-D2A287B66D60}
AppName=Lycri
AppVersion=1.0.0
AppPublisher=com.lycri
AppPublisherURL=https://lycri.app
AppSupportURL=https://lycri.app
AppUpdatesURL=https://lycri.app
DefaultDirName={autopf}\Lycri
DisableProgramGroupPage=yes
; Remove the following line to run in administrative install mode (install for all users.)
PrivilegesRequired=lowest
OutputDir=build\installer
OutputBaseFilename=Lycri_Setup_v1.0.0
SetupIconFile=windows\runner\resources\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\lycri_lyrics.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Note: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\Lycri"; Filename: "{app}\lycri_lyrics.exe"
Name: "{autodesktop}\Lycri"; Filename: "{app}\lycri_lyrics.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\lycri_lyrics.exe"; Description: "{cm:LaunchProgram,Lycri}"; Flags: nowait postinstall skipifsilent
