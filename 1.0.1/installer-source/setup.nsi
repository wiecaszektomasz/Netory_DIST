Unicode true
!ifndef APP_VERSION
!define APP_VERSION "1.0.1"
!endif
Name "Netory ${APP_VERSION} Setup"
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "Netory"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "FileVersion" "${APP_VERSION}.0"
VIAddVersionKey "FileDescription" "Netory Windows installer"
VIAddVersionKey "LegalCopyright" "Netory"
OutFile "${OUTPUT_EXE}"
RequestExecutionLevel admin
SilentInstall silent
SetCompressor /SOLID lzma
!include "x64.nsh"
Section
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Netory requires 64-bit Windows."
    SetErrorLevel 1
    Quit
  ${EndIf}
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\NetorySetup"
  File /r "${BUNDLE_DIR}/*"
  ExecWait '"$WINDIR\Sysnative\WindowsPowerShell\v1.0\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "$PLUGINSDIR\NetorySetup\Setup.ps1"' $0
  SetErrorLevel $0
SectionEnd
