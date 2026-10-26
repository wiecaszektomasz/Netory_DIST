# Compatible with the built-in Windows PowerShell 5.1. No Internet access required.
param([ValidateSet('Install','Configure','Uninstall')][string]$Mode='Install')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Run this installer on 64-bit Windows.' }
if (-not [Environment]::Is64BitProcess) { throw 'Run Install.cmd or Netory-Setup.exe to use 64-bit PowerShell.' }
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments='-STA -NoProfile -ExecutionPolicy Bypass -File "'+$PSCommandPath+'" -Mode '+$Mode
    $elevated=Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList $arguments -Verb RunAs -Wait -PassThru
    exit $elevated.ExitCode
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$InstallRoot=Join-Path $env:ProgramFiles 'Netory'
$DataRoot=Join-Path $env:ProgramData 'Netory'
# Locate custom storage on updates, configuration and uninstall.
$location=Get-ItemProperty 'HKLM:\Software\Netory' -ErrorAction SilentlyContinue
if($location){$InstallRoot=[string]$location.InstallRoot;$DataRoot=[string]$location.DataRoot}
$Https=$false;$Hostname='localhost';$Certificate='';$CertificatePassword=''
$ServiceExe=Join-Path $InstallRoot 'service\Netory.exe'
$SettingsPath=Join-Path $DataRoot 'settings.json'
$FirewallName='Netory-Private-LAN'
$Utf8=New-Object Text.UTF8Encoding($false)
function Run-Checked([string]$File,[string[]]$Arguments) {
    & $File @Arguments | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "Operation failed: $(Split-Path $File -Leaf) (exit $LASTEXITCODE). Check the installation log." }
}
function Stop-Netory {
    $service=Get-Service -Name Netory -ErrorAction SilentlyContinue
    if ($service -and $service.Status -ne 'Stopped') { Stop-Service Netory; $service.WaitForStatus('Stopped',[TimeSpan]::FromSeconds(45)) }
}
function Protect-Data {
    New-Item -ItemType Directory -Path $DataRoot -Force | Out-Null
    Run-Checked icacls.exe @($DataRoot,'/inheritance:r','/grant:r','*S-1-5-18:(OI)(CI)F','*S-1-5-32-544:(OI)(CI)F','*S-1-5-19:(OI)(CI)RX')
    foreach ($name in @('db','logs','backups','tls')) {
        $directory=Join-Path $DataRoot $name
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        if ($name -eq 'tls') { Run-Checked icacls.exe @($directory,'/inheritance:r','/grant:r','*S-1-5-18:(OI)(CI)F','*S-1-5-32-544:(OI)(CI)F','*S-1-5-19:(OI)(CI)RX') }
        elseif ($name -ne 'backups') { Run-Checked icacls.exe @($directory,'/grant:r','*S-1-5-19:(OI)(CI)M') }
        else { Run-Checked icacls.exe @($directory,'/inheritance:r','/grant:r','*S-1-5-18:(OI)(CI)F','*S-1-5-32-544:(OI)(CI)F') }
    }
}
function Run-Python([string]$Python,[string]$Arguments,[string]$InputJson='') {
    $info=New-Object Diagnostics.ProcessStartInfo
    $info.FileName=$Python; $info.Arguments=$Arguments; $info.WorkingDirectory=$DataRoot
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $info.EnvironmentVariables['PYTHONUTF8']='1'; $info.EnvironmentVariables['PYTHONDONTWRITEBYTECODE']='1'
    $process=New-Object Diagnostics.Process; $process.StartInfo=$info
    [void]$process.Start()
    $stdout=$process.StandardOutput.ReadToEndAsync(); $stderr=$process.StandardError.ReadToEndAsync()
    if ($InputJson) {
        $asciiJson=[regex]::Replace($InputJson,'[^\x00-\x7F]',{param($match) '\u{0:x4}' -f [int][char]$match.Value})
        $process.StandardInput.Write($asciiJson)
    }
    $process.StandardInput.Close()
    while(-not $process.WaitForExit(150)){[Windows.Forms.Application]::DoEvents()}
    $output=$stdout.GetAwaiter().GetResult(); $errors=$stderr.GetAwaiter().GetResult()
    [IO.File]::AppendAllText((Join-Path $DataRoot 'logs\setup.log'),$output+$errors,$Utf8)
    if ($process.ExitCode -ne 0) { throw ("Setup check failed. See "+(Join-Path $DataRoot 'logs\setup.log')+' for details.') }
}
function Write-Service([int]$Port,[bool]$Lan) {
    $escape={param($v)[Security.SecurityElement]::Escape([string]$v)}
    $python=& $escape (Join-Path $InstallRoot 'runtime\python.exe')
    $working=& $escape $DataRoot
    $logpath=& $escape (Join-Path $DataRoot 'logs')
    $bind=if($Lan){'0.0.0.0'}else{'127.0.0.1'}
    $tlsArguments=''
    if($Https){$tlsArguments=' --ssl-certfile &quot;'+(& $escape (Join-Path $DataRoot 'tls\server.pem'))+'&quot; --ssl-keyfile &quot;'+(& $escape (Join-Path $DataRoot 'tls\server.key'))+'&quot;'}
    $xml=@"
<service>
 <id>Netory</id><name>Netory</name><description>Netory IT inventory application</description>
 <executable>$python</executable>
 <arguments>-m uvicorn backend.main:app --host $bind --port $Port --workers 1 --no-server-header$tlsArguments</arguments>
 <workingdirectory>$working</workingdirectory>
 <env name="PYTHONUTF8" value="1"/><env name="PYTHONDONTWRITEBYTECODE" value="1"/>
 <startmode>Automatic</startmode><stoptimeout>30 sec</stoptimeout>
 <onfailure action="restart" delay="10 sec"/>
 <serviceaccount><domain>NT AUTHORITY</domain><user>LocalService</user></serviceaccount>
 <logpath>$logpath</logpath><log mode="roll-by-size"><sizeThreshold>10240</sizeThreshold><keepFiles>7</keepFiles></log>
</service>
"@
    [IO.File]::WriteAllText((Join-Path $InstallRoot 'service\Netory.xml'),$xml,$Utf8)
}
function Update-Firewall([int]$Port,[bool]$Lan) {
    Get-NetFirewallRule -Name $FirewallName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    if ($Lan) { New-NetFirewallRule -Name $FirewallName -DisplayName 'Netory (private local network)' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -Profile Private -RemoteAddress LocalSubnet -Program (Join-Path $InstallRoot 'runtime\python.exe') | Out-Null }
}
function Wait-Netory([int]$Port) {
    for($attempt=0;$attempt -lt 40;$attempt++) {
        try {
            Run-Python (Join-Path $InstallRoot 'runtime\python.exe') ('"'+(Join-Path $InstallRoot 'tools\bootstrap.py')+'" health --app "'+(Join-Path $InstallRoot 'app')+'" --data "'+$DataRoot+'"') (@{port=$Port;https=$Https;hostname=$Hostname}|ConvertTo-Json -Compress)
            if((Get-Service Netory).Status -eq 'Running'){return}
        } catch {}
        [Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds 500
    }
    throw ('The service did not become ready. Check '+(Join-Path $DataRoot 'logs'))
}
function Get-NetoryUrl([int]$Port) {
    if($Https){return "https://${Hostname}:$Port/"}
    return "http://127.0.0.1:$Port/"
}
function Create-Shortcuts([int]$Port) {
    $menu=Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Netory'
    New-Item -ItemType Directory -Path $menu -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $menu 'Open Netory.url'),"[InternetShortcut]`r`nURL=$(Get-NetoryUrl $Port)`r`n",$Utf8)
    $shell=New-Object -ComObject WScript.Shell
    foreach($entry in @(@('Configure Netory','Configure'),@('Uninstall Netory','Uninstall'))) {
        $shortcut=$shell.CreateShortcut((Join-Path $menu ($entry[0]+'.lnk')))
        $shortcut.TargetPath="$PSHOME\powershell.exe"
        $shortcut.Arguments='-STA -NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $InstallRoot 'Setup.ps1')+'" -Mode '+$entry[1]
        $shortcut.Save()
    }
    New-Item 'HKLM:\Software\Netory' -Force | Out-Null
    New-ItemProperty 'HKLM:\Software\Netory' -Name InstallRoot -Value $InstallRoot -PropertyType String -Force | Out-Null
    New-ItemProperty 'HKLM:\Software\Netory' -Name DataRoot -Value $DataRoot -PropertyType String -Force | Out-Null
    $registry='HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Netory'
    New-Item $registry -Force | Out-Null
    New-ItemProperty $registry -Name DisplayName -Value 'Netory' -PropertyType String -Force | Out-Null
    New-ItemProperty $registry -Name Publisher -Value 'Netory' -PropertyType String -Force | Out-Null
    New-ItemProperty $registry -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
    New-ItemProperty $registry -Name UninstallString -Value ('"'+$PSHOME+'\powershell.exe" -STA -NoProfile -ExecutionPolicy Bypass -File "'+(Join-Path $InstallRoot 'Setup.ps1')+'" -Mode Uninstall') -PropertyType String -Force | Out-Null
}
function Install-Netory([int]$Port,[bool]$Lan,[string]$Username,[string]$Password) {
    $existing=Get-Service Netory -ErrorAction SilentlyContinue
    $oldSettings=$null
    if(Test-Path $SettingsPath){$oldSettings=Get-Content $SettingsPath -Raw | ConvertFrom-Json}
    $listeners=@(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
    if($listeners.Count -and (-not $oldSettings -or [int]$oldSettings.port -ne $Port -or -not $existing)){throw "Port $Port is already in use. Choose a different port."}
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $backupPath=Join-Path $DataRoot ('backups\'+$stamp)
    $previous=$InstallRoot+'.previous-'+$stamp
    $stage=$InstallRoot+'.staging-'+$stamp
    $moved=$false; $createdService=$false; $started=$false
    Protect-Data
    try {
        if($Mode -eq 'Install') {
            $manifest=Get-Content (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
            foreach($file in $manifest.files.PSObject.Properties) {
                $path=Join-Path $PSScriptRoot $file.Name
                if((Get-FileHash -Algorithm SHA256 -LiteralPath $path).Hash.ToLowerInvariant() -ne $file.Value){throw ('Installer integrity check failed: '+$file.Name)}
            }
            New-Item -ItemType Directory -Path $stage | Out-Null
            Copy-Item (Join-Path $PSScriptRoot 'payload\*') $stage -Recurse -Force
            Copy-Item $PSCommandPath (Join-Path $stage 'Setup.ps1')
            Copy-Item (Join-Path $PSScriptRoot 'SetupForm.ps1') (Join-Path $stage 'SetupForm.ps1')
            $vc=Join-Path $stage 'prerequisites\vc_redist.x64.exe'
            $signature=Get-AuthenticodeSignature -LiteralPath $vc
            if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch 'Microsoft Corporation'){throw 'The Microsoft runtime installer signature could not be verified.'}
            $vcProcess=Start-Process -FilePath $vc -ArgumentList '/install /quiet /norestart' -PassThru
            while(-not $vcProcess.WaitForExit(150)){[Windows.Forms.Application]::DoEvents()}
            if($vcProcess.ExitCode -notin @(0,1638,3010)){throw ('Microsoft runtime setup failed: '+$vcProcess.ExitCode)}
            Run-Python (Join-Path $stage 'runtime\python.exe') '-c "import sqlite3,uvicorn,sqlalchemy,cryptography,argon2; print(sqlite3.sqlite_version)"'
        }
        Stop-Netory
        if(@(Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue).Count){throw "Port $Port is already in use by another process."}
        if(Test-Path (Join-Path $InstallRoot 'runtime\python.exe')) {
            Run-Python (Join-Path $InstallRoot 'runtime\python.exe') ('"'+(Join-Path $InstallRoot 'tools\bootstrap.py')+'" backup --app "'+(Join-Path $InstallRoot 'app')+'" --data "'+$DataRoot+'" --destination "'+$backupPath+'"')
        }
        elseif($Mode -eq 'Install' -and (Test-Path (Join-Path $DataRoot 'db\netory.db'))) {
            Run-Python (Join-Path $stage 'runtime\python.exe') ('"'+(Join-Path $stage 'tools\bootstrap.py')+'" backup --app "'+(Join-Path $stage 'app')+'" --data "'+$DataRoot+'" --destination "'+$backupPath+'"')
        }
        if($Mode -eq 'Install') {
            if(Test-Path $InstallRoot){Move-Item $InstallRoot $previous; $moved=$true}
            Move-Item $stage $InstallRoot
        } else {
            New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
            Copy-Item (Join-Path $InstallRoot 'service\Netory.xml') (Join-Path $backupPath 'Netory.xml')
        }
        New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
        if(Test-Path (Join-Path $DataRoot 'tls\server.pem')){Copy-Item (Join-Path $DataRoot 'tls\server.*') $backupPath}
        if($Https){
            Run-Python (Join-Path $InstallRoot 'runtime\python.exe') ('"'+(Join-Path $InstallRoot 'tools\bootstrap.py')+'" certificate --app "'+(Join-Path $InstallRoot 'app')+'" --data "'+$DataRoot+'"') (@{hostname=$Hostname;certificate=$Certificate;certificate_password=$CertificatePassword}|ConvertTo-Json -Compress)
        }
        Run-Checked icacls.exe @($InstallRoot,'/grant:r','*S-1-5-19:(OI)(CI)RX')
        Run-Python (Join-Path $InstallRoot 'runtime\python.exe') ('"'+(Join-Path $InstallRoot 'tools\bootstrap.py')+'" setup --app "'+(Join-Path $InstallRoot 'app')+'" --data "'+$DataRoot+'"') (@{username=$Username;password=$Password;https=$Https}|ConvertTo-Json -Compress)
        Run-Checked icacls.exe @((Join-Path $DataRoot '.env'),'/inheritance:r','/grant:r','*S-1-5-18:F','*S-1-5-32-544:F','*S-1-5-19:R')
        Write-Service $Port $Lan
        if(-not $existing){Run-Checked $ServiceExe @('install');$createdService=$true}
        Start-Service Netory
        Wait-Netory $Port
        Update-Firewall $Port $Lan
        [IO.File]::WriteAllText($SettingsPath,(@{port=$Port;lan=$Lan;https=$Https;hostname=$Hostname;installRoot=$InstallRoot;dataRoot=$DataRoot}|ConvertTo-Json),$Utf8)
        Create-Shortcuts $Port
        $started=$true
        if($moved){Remove-Item $previous -Recurse -Force}
    } catch {
        $failure=$_
        try {
            Stop-Netory
            if($createdService){Run-Checked $ServiceExe @('uninstall')}
            if($moved){Remove-Item $InstallRoot -Recurse -Force;Move-Item $previous $InstallRoot}
            if(Test-Path (Join-Path $backupPath '.env')){Copy-Item (Join-Path $backupPath '.env') (Join-Path $DataRoot '.env') -Force}
            if(Test-Path (Join-Path $backupPath 'netory.db')) {
                foreach($suffix in @('-wal','-shm')){Remove-Item ((Join-Path $DataRoot 'db\netory.db')+$suffix) -ErrorAction SilentlyContinue}
                Copy-Item (Join-Path $backupPath 'netory.db') (Join-Path $DataRoot 'db\netory.db') -Force
            }
            foreach($tlsFile in @('server.pem','server.key')){
                if(Test-Path (Join-Path $backupPath $tlsFile)){Copy-Item (Join-Path $backupPath $tlsFile) (Join-Path $DataRoot ('tls\'+$tlsFile)) -Force}
            }
            if($Mode -eq 'Configure' -and (Test-Path (Join-Path $backupPath 'Netory.xml'))){Copy-Item (Join-Path $backupPath 'Netory.xml') (Join-Path $InstallRoot 'service\Netory.xml') -Force}
            if($oldSettings){Update-Firewall ([int]$oldSettings.port) ([bool]$oldSettings.lan);[IO.File]::WriteAllText($SettingsPath,($oldSettings|ConvertTo-Json),$Utf8)}
            if($existing){Start-Service Netory}
        } catch { [Windows.Forms.MessageBox]::Show('Automatic recovery needs attention. Preserve C:\ProgramData\Netory and inspect setup.log.','Netory') | Out-Null }
        throw $failure
    } finally {if(Test-Path $stage){Remove-Item $stage -Recurse -Force}}
}
if($Mode -eq 'Uninstall') {
    if([Windows.Forms.MessageBox]::Show(("Remove the Netory service and program? Database, encryption keys and backups will be kept in $DataRoot."),'Uninstall Netory','YesNo','Question') -ne 'Yes'){exit 0}
    Stop-Netory
    if(Get-Service Netory -ErrorAction SilentlyContinue){Run-Checked $ServiceExe @('uninstall')}
    Get-NetFirewallRule -Name $FirewallName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
    Remove-Item (Join-Path ([Environment]::GetFolderPath('CommonPrograms')) 'Netory') -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Netory' -Recurse -Force -ErrorAction SilentlyContinue
    if(Test-Path $InstallRoot){Remove-Item $InstallRoot -Recurse -Force}
    [Windows.Forms.MessageBox]::Show('Netory removed. Your database and configuration have been kept.','Netory') | Out-Null
    exit 0
}
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'SetupForm.ps1')
$saved=$null
if(Test-Path $SettingsPath){$saved=Get-Content $SettingsPath -Raw|ConvertFrom-Json}
$window=New-NetorySetupForm -SavedSettings $saved -Mode $Mode -InstallRoot $InstallRoot -DataRoot $DataRoot
$form=$window.Form;$fieldsPanel=$window.FieldsPanel
$portBox=$window.Port;$lanBox=$window.Lan;$nameBox=$window.Username
$passwordBox=$window.Password;$confirmBox=$window.Confirm
$installButton=$window.Install;$cancelButton=$window.Cancel
$installButton.Add_Click({
    try {
        $port=0;if(-not [int]::TryParse($portBox.Text,[ref]$port) -or $port -lt 1 -or $port -gt 65535){throw 'Enter a port between 1 and 65535.'}
        if($passwordBox.Enabled -and ($passwordBox.Text.Length -lt 14 -or $passwordBox.Text -cne $confirmBox.Text -or -not $nameBox.Text.Trim())){throw 'Enter a username and matching passwords of at least 14 characters.'}
        if(-not $saved){
            $application=[IO.Path]::GetFullPath($window.Application.Text.Trim()).TrimEnd('\')
            $data=[IO.Path]::GetFullPath($window.Data.Text.Trim()).TrimEnd('\')
            foreach($path in @($application,$data)){
                if($path -notmatch '^[A-Za-z]:\\.+') {throw 'Choose dedicated folders on a local drive, not a drive root or network share.'}
                foreach($reserved in @($env:windir,$env:ProgramFiles,${env:ProgramFiles(x86)},$env:ProgramData)){
                    if($reserved -and ($path.Equals($reserved,[StringComparison]::OrdinalIgnoreCase) -or ($reserved -eq $env:windir -and $path.StartsWith($reserved+'\',[StringComparison]::OrdinalIgnoreCase)))){throw 'Choose a dedicated Netory folder, not a Windows system folder.'}
                }
                if($path.Contains('"')){throw 'Folder names cannot contain quotation marks.'}
                $drive=New-Object IO.DriveInfo([IO.Path]::GetPathRoot($path))
                if($drive.DriveType -ne 'Fixed'){throw 'Use a fixed local disk for the application and database.'}
            }
            if($application.Equals($data,[StringComparison]::OrdinalIgnoreCase) -or $data.StartsWith($application+'\',[StringComparison]::OrdinalIgnoreCase) -or $application.StartsWith($data+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Application and data folders must be separate and must not contain one another.'}
            if((Test-Path $application) -and @(Get-ChildItem $application -Force).Count -and -not (Get-Service Netory -ErrorAction SilentlyContinue)){throw 'Choose an empty application folder.'}
            if((Test-Path $data) -and @(Get-ChildItem $data -Force).Count -and -not ((Test-Path (Join-Path $data '.env')) -and (Test-Path (Join-Path $data 'db\netory.db')))){throw 'Choose an empty data folder or an existing Netory data folder containing .env and db/netory.db.'}
            if($application -ne $InstallRoot -and (Get-Service Netory -ErrorAction SilentlyContinue)){throw 'An existing service must be updated in its current application folder.'}
            $script:InstallRoot=$application;$script:DataRoot=$data
            $script:ServiceExe=Join-Path $InstallRoot 'service\Netory.exe'
            $script:SettingsPath=Join-Path $DataRoot 'settings.json'
        }
        $script:Https=$window.Https.Checked;$script:Hostname=$window.Hostname.Text.Trim()
        $script:Certificate=$window.Certificate.Text.Trim();$script:CertificatePassword=$window.CertificatePassword.Text
        if($Https -and (-not $Hostname -or $Hostname -match '[^a-zA-Z0-9.\-]')){throw 'Enter the certificate DNS name or IPv4 address without a scheme, port or path.'}
        if($Https -and -not $Certificate -and -not (Test-Path (Join-Path $DataRoot 'tls\server.pem'))){throw 'Choose a PFX certificate with its private key to enable HTTPS.'}
        if($Https -and $Certificate -and -not (Test-Path -LiteralPath $Certificate -PathType Leaf)){throw 'The selected certificate file does not exist.'}
        $installButton.Enabled=$false;$cancelButton.Enabled=$false;$fieldsPanel.Enabled=$false;$form.UseWaitCursor=$true;$form.Text='Netory Setup - working...';$form.Refresh()
        Install-Netory $port $lanBox.Checked $nameBox.Text $passwordBox.Text
        $passwordBox.Clear();$confirmBox.Clear();$window.CertificatePassword.Clear();$script:CertificatePassword=''
        [Windows.Forms.MessageBox]::Show("Netory is running at $(Get-NetoryUrl $port)`nUse the Start menu shortcuts to open or configure it.",'Netory installed')|Out-Null
        $form.UseWaitCursor=$false;$form.Close();Start-Process (Get-NetoryUrl $port)
    } catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Netory Setup','OK','Error')|Out-Null }
    finally {$form.UseWaitCursor=$false;$fieldsPanel.Enabled=$true;$cancelButton.Enabled=$true;$installButton.Enabled=$true;$form.Text='Netory Setup'}
})
$form.Add_FormClosing({param($sender,$eventArgs) if($form.UseWaitCursor){$eventArgs.Cancel=$true}})
[void]$form.ShowDialog()
