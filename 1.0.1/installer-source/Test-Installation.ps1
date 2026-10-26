# Run in an elevated Windows PowerShell after completing installation.
param([string]$ExpectedVersion='1.0.1')
$ErrorActionPreference='Stop'
$installRoot=Join-Path $env:ProgramFiles 'Netory'
$dataRoot=Join-Path $env:ProgramData 'Netory'
$location=Get-ItemProperty 'HKLM:\Software\Netory' -ErrorAction SilentlyContinue
if($location){$installRoot=$location.InstallRoot;$dataRoot=$location.DataRoot}
$version=Get-Content (Join-Path $installRoot 'version.json') -Raw|ConvertFrom-Json
if($version.version -ne $ExpectedVersion){throw "Installed version is not $ExpectedVersion."}
$uninstall=Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Netory'
if($uninstall.DisplayVersion -ne $ExpectedVersion){throw 'Windows installed-app version does not match.'}
$settings=Get-Content (Join-Path $dataRoot 'settings.json') -Raw|ConvertFrom-Json
$service=Get-CimInstance Win32_Service -Filter "Name='Netory'"
if(-not $service -or $service.State -ne 'Running'){throw 'Netory service is not running.'}
if($service.StartMode -ne 'Auto'){throw 'Service startup is not automatic.'}
if($service.StartName -notmatch 'LocalService|LOCAL SERVICE'){throw 'Service is not using the restricted LocalService identity.'}
$https=$false;$hostname='localhost'
if($settings.PSObject.Properties['https']){$https=[bool]$settings.https;$hostname=$settings.hostname}
@{port=$settings.port;https=$https;hostname=$hostname}|ConvertTo-Json -Compress | & "$installRoot\runtime\python.exe" "$installRoot\tools\bootstrap.py" health --app "$installRoot\app" --data $dataRoot
if($LASTEXITCODE -ne 0){throw 'Netory did not serve its application page.'}
if(-not (Test-Path "$dataRoot\db\netory.db")){throw 'Database is missing.'}
if(-not (Test-Path "$dataRoot\.env")){throw 'Application configuration is missing.'}
Write-Host "Netory service, account, startup, HTTP/HTTPS port $($settings.port), database and configuration passed."
Write-Host 'Next: sign in, create a client/asset, change the port, restart Windows, test update and uninstall preservation on a test PC.'
