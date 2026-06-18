#define MyAppName "听悦"
#define MyAppPublisher "Ting Reader"
#define MyAppURL "https://www.tingreader.cn"
#define MyAppExeName "ting_reader_flutter.exe"
#define MyEnvVersion GetEnv("TING_READER_VERSION")
#define MyEnvBuildDir GetEnv("TING_READER_BUILD_DIR")
#define MyEnvOutputDir GetEnv("TING_READER_OUTPUT_DIR")

#if MyEnvVersion == ""
#define MyAppVersion "1.0.0"
#else
#define MyAppVersion MyEnvVersion
#endif

#if MyEnvBuildDir == ""
#define MyBuildDir "..\..\build\windows\x64\runner\Release"
#else
#define MyBuildDir MyEnvBuildDir
#endif

#if MyEnvOutputDir == ""
#define MyOutputDir "..\..\dist"
#else
#define MyOutputDir MyEnvOutputDir
#endif

[Setup]
AppId={{6A15B4CE-7E1A-4E1B-93DB-6E7C9E5E7D6F}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Ting Reader
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#MyOutputDir}
OutputBaseFilename=TingReader-windows-x64-setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=setup_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#MyBuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
