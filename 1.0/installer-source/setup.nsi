Unicode true
Name "Netory Setup"
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
