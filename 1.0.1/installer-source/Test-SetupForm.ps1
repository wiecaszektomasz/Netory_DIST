# Run with Windows PowerShell -STA on an interactive Windows desktop. No installation occurs.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if($env:OS -ne 'Windows_NT'){throw 'This UI smoke check requires Windows.'}
if([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA'){throw 'Run powershell.exe -STA -File Test-SetupForm.ps1'}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
. (Join-Path $PSScriptRoot 'SetupForm.ps1')
function Assert([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Test-EditableField($Window,$Control,[string]$Value) {
    $Window.FieldsPanel.ScrollControlIntoView($Control);[Windows.Forms.Application]::DoEvents()
    Assert ($Control.Enabled -and -not $Control.ReadOnly) ($Control.Name+' is not editable')
    Assert ($Control.Focus()) ($Control.Name+' cannot receive focus')
    $Control.SelectAll();$Control.SelectedText=$Value
    Assert ($Control.Text -ceq $Value) ($Control.Name+' did not accept input')
    $point=$Control.PointToScreen((New-Object Drawing.Point([int]($Control.Width/2),[int]($Control.Height/2))))
    $hit=$Window.Form
    while($hit.HasChildren){$child=$hit.GetChildAtPoint($hit.PointToClient($point));if($null -eq $child){break};$hit=$child}
    Assert ([object]::ReferenceEquals($hit,$Control)) ($Control.Name+' is covered by another control')
    Assert ($Control.Parent.GetColumn($Control) -eq 1) ($Control.Name+' is outside the input column')
}
foreach($scale in @(1.0,1.5,2.0)) {
    $window=New-NetorySetupForm
    try {
        $window.Form.Scale((New-Object Drawing.SizeF($scale,$scale)))
        $window.Form.Show();$window.Form.PerformLayout();[Windows.Forms.Application]::DoEvents()
        Test-EditableField $window $window.Port '8123'
        Test-EditableField $window $window.Username 'TestAdmin'
        Test-EditableField $window $window.Password 'test-password-1234'
        Test-EditableField $window $window.Confirm 'test-password-1234'
        Assert ($window.Password.UseSystemPasswordChar -and $window.Confirm.UseSystemPasswordChar) 'Passwords must stay masked'
        Assert ($window.Port.TabIndex -lt $window.Username.TabIndex -and $window.Username.TabIndex -lt $window.Password.TabIndex -and $window.Password.TabIndex -lt $window.Confirm.TabIndex) 'Incorrect keyboard tab order'
    } finally {$window.Form.Close();$window.Form.Dispose()}
}
$window=New-NetorySetupForm -SavedSettings ([PSCustomObject]@{port=8123;lan=$true}) -Mode Configure
try {
    $window.Form.Show();[Windows.Forms.Application]::DoEvents()
    Test-EditableField $window $window.Port '8124'
    Assert ($window.Lan.Enabled) 'Network setting must remain editable'
    Assert (-not $window.Username.Enabled -and -not $window.Password.Enabled -and -not $window.Confirm.Enabled) 'Existing accounts must not be overwritten in Configure mode'
    Assert ($window.Install.Text -eq 'Save and restart') 'Incorrect Configure action'
} finally {$window.Form.Close();$window.Form.Dispose()}
Write-Host 'Setup form input, hit testing, scaling, password masking and Configure checks passed.'
