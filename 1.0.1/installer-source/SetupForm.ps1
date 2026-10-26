# Pure Windows Forms layout: safe to smoke-test without installing a service.
function New-NetorySetupForm([object]$SavedSettings=$null,[string]$Mode='Install',[string]$InstallRoot="",[string]$DataRoot="") {
    $form=New-Object Windows.Forms.Form
    $form.Text='Netory Setup'
    $form.Font=New-Object Drawing.Font('Segoe UI',9)
    $form.AutoScaleDimensions=New-Object Drawing.SizeF(7,15)
    $form.AutoScaleMode=[Windows.Forms.AutoScaleMode]::Font
    $form.ClientSize=New-Object Drawing.Size(740,740)
    $form.MinimumSize=New-Object Drawing.Size(700,720)
    $form.StartPosition='CenterScreen'
    $form.MaximizeBox=$false
    $form.BackColor=[Drawing.Color]::FromArgb(245,247,250)

    $grid=New-Object Windows.Forms.TableLayoutPanel
    $grid.Name='SettingsPanel';$grid.Dock='Fill';$grid.Padding=New-Object Windows.Forms.Padding(20)
    $grid.ColumnCount=2;$grid.RowCount=18;$grid.AutoScroll=$true;$grid.TabIndex=0
    [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,34)))
    [void]$grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,66)))
    for($row=0;$row -lt 18;$row++){[void]$grid.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::AutoSize)))}
    $form.Controls.Add($grid)

    function Add-SetupMessage([string]$Text,[int]$Row) {
        $label=New-Object Windows.Forms.Label
        $label.Text=$Text;$label.AutoSize=$true;$label.Dock='Fill'
        $label.MaximumSize=New-Object Drawing.Size(650,0)
        $label.Margin=New-Object Windows.Forms.Padding(0,5,0,12)
        $grid.Controls.Add($label,0,$Row);$grid.SetColumnSpan($label,2)
    }
    function Add-SetupField([string]$Text,[string]$Name,[int]$Row,[int]$TabIndex,[bool]$Secret=$false) {
        $label=New-Object Windows.Forms.Label
        $label.Text=$Text;$label.AutoSize=$true;$label.Dock='Fill';$label.TextAlign='MiddleLeft'
        $label.Margin=New-Object Windows.Forms.Padding(0,6,12,10)
        $grid.Controls.Add($label,0,$Row)
        $control=New-Object Windows.Forms.TextBox
        $control.Name=$Name;$control.AccessibleName=$Text;$control.Dock='Fill';$control.TabIndex=$TabIndex
        $control.Margin=New-Object Windows.Forms.Padding(0,6,0,10)
        $control.UseSystemPasswordChar=$Secret
        $grid.Controls.Add($control,1,$Row)
        return $control
    }
    function Add-SetupPath([string]$Text,[string]$Name,[int]$Row,[string]$Value,[bool]$File=$false) {
        $box=Add-SetupField $Text $Name $Row $Row
        $box.Text=$Value
        $grid.Controls.Remove($box)
        $panel=New-Object Windows.Forms.TableLayoutPanel
        $panel.Dock='Fill';$panel.AutoSize=$true;$panel.ColumnCount=2;$panel.Margin=New-Object Windows.Forms.Padding(0)
        [void]$panel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Percent,100)))
        [void]$panel.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute,85)))
        $button=New-Object Windows.Forms.Button
        $button.Text='Browse...';$button.Dock='Fill';$button.Margin=New-Object Windows.Forms.Padding(8,4,0,8)
        $button.Tag=@{Box=$box;File=$File}
        $button.Add_Click({
            $target=$this.Tag.Box
            if($this.Tag.File){
                $dialog=New-Object Windows.Forms.OpenFileDialog
                $dialog.Filter='Certificate with private key (*.pfx;*.p12)|*.pfx;*.p12'
                if($dialog.ShowDialog() -eq 'OK'){$target.Text=$dialog.FileName}
            } else {
                $dialog=New-Object Windows.Forms.FolderBrowserDialog
                $dialog.Description='Choose a dedicated Netory folder';$dialog.SelectedPath=$target.Text
                if($dialog.ShowDialog() -eq 'OK'){$target.Text=$dialog.SelectedPath}
            }
            $dialog.Dispose()
        })
        $panel.Controls.Add($box,0,0);$panel.Controls.Add($button,1,0)
        $grid.Controls.Add($panel,1,$Row)
        return $box
    }
    Add-SetupMessage 'NETORY  |  Application setup' 0
    $grid.GetControlFromPosition(0,0).Font=New-Object Drawing.Font('Segoe UI',17,[Drawing.FontStyle]::Bold)
    $grid.GetControlFromPosition(0,0).ForeColor=[Drawing.Color]::FromArgb(31,73,125)
    Add-SetupMessage 'Installation & storage   /   Python, SQLite and the Windows service are included.' 1
    $applicationBox=Add-SetupPath 'Application folder' 'ApplicationFolder' 2 $InstallRoot
    $dataBox=Add-SetupPath 'Database & data folder' 'DataFolder' 3 $DataRoot
    Add-SetupMessage 'The data folder keeps the SQLite database, configuration, encryption keys and backups. Use a dedicated local folder outside the application folder.' 4
    Add-SetupMessage 'Network & HTTPS' 5
    $portBox=Add-SetupField 'Network &port' 'Port' 6 6
    $portBox.Text='8000';$portBox.MaxLength=5
    $lanBox=New-Object Windows.Forms.CheckBox
    $lanBox.Name='AllowLan';$lanBox.Text='Allow access from the private local network'
    $lanBox.AutoSize=$true;$lanBox.Dock='Fill';$lanBox.TabIndex=7
    $grid.Controls.Add($lanBox,1,7)
    $httpsBox=New-Object Windows.Forms.CheckBox
    $httpsBox.Text='Use HTTPS';$httpsBox.AutoSize=$true;$httpsBox.Dock='Fill';$httpsBox.TabIndex=8
    $grid.Controls.Add($httpsBox,1,8)
    $hostBox=Add-SetupField 'Certificate DNS name / IP' 'ServerName' 9 9
    $hostBox.Text='localhost'
    $certificateBox=Add-SetupPath 'Certificate (.pfx / .p12)' 'Certificate' 10 '' $true
    $certificatePassword=Add-SetupField 'Certificate password' 'CertificatePassword' 11 11 $true
    Add-SetupMessage 'Use a certificate issued for the DNS name or IP above, including its private key and intermediate certificates. Browsers must trust its issuer. Leave the certificate blank to keep the current one during configuration.' 12
    Add-SetupMessage 'Administrator' 13
    $nameBox=Add-SetupField 'Administrator &username' 'Username' 14 14
    $nameBox.Text='admin';$nameBox.MaxLength=120
    $passwordBox=Add-SetupField '&Password (14+ characters)' 'Password' 15 15 $true
    $confirmBox=Add-SetupField '&Confirm password' 'ConfirmPassword' 16 16 $true
    $passwordBox.MaxLength=1024;$confirmBox.MaxLength=1024
    if($null -ne $SavedSettings) {
        $portBox.Text=[string]$SavedSettings.port;$lanBox.Checked=[bool]$SavedSettings.lan
        if($SavedSettings.PSObject.Properties['https']){$httpsBox.Checked=[bool]$SavedSettings.https}
        if($SavedSettings.PSObject.Properties['hostname']){$hostBox.Text=[string]$SavedSettings.hostname}
        $applicationBox.Parent.Enabled=$false;$dataBox.Parent.Enabled=$false
        $nameBox.Enabled=$false;$passwordBox.Enabled=$false;$confirmBox.Enabled=$false
        Add-SetupMessage 'Existing storage locations and administrator accounts are preserved. Change account credentials inside Netory.' 17
    }
    foreach($row in @(1,5,13)){
        $heading=$grid.GetControlFromPosition(0,$row)
        $heading.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
        $heading.ForeColor=[Drawing.Color]::FromArgb(31,73,125)
    }
    $httpsBox.Tag=@($hostBox,$certificateBox.Parent,$certificatePassword)
    $httpsBox.Add_CheckedChanged({foreach($control in $this.Tag){$control.Enabled=$this.Checked}})
    foreach($control in $httpsBox.Tag){$control.Enabled=$httpsBox.Checked}

    $actions=New-Object Windows.Forms.FlowLayoutPanel
    $actions.Dock='Bottom';$actions.Height=65;$actions.FlowDirection='RightToLeft'
    $actions.Padding=New-Object Windows.Forms.Padding(14,10,14,10);$actions.TabIndex=1
    $installButton=New-Object Windows.Forms.Button
    $installButton.Text=if($null -eq $SavedSettings){'Install Netory'}elseif($Mode -eq 'Configure'){'Save and restart'}else{'Update Netory'}
    $installButton.BackColor=[Drawing.Color]::FromArgb(31,73,125);$installButton.ForeColor=[Drawing.Color]::White;$installButton.FlatStyle='Flat'
    $installButton.Name='Install';$installButton.Size=New-Object Drawing.Size(175,32);$installButton.TabIndex=0
    $cancelButton=New-Object Windows.Forms.Button
    $cancelButton.Text='Cancel';$cancelButton.Size=New-Object Drawing.Size(90,32);$cancelButton.TabIndex=1
    $cancelButton.DialogResult=[Windows.Forms.DialogResult]::Cancel
    $actions.Controls.Add($installButton);$actions.Controls.Add($cancelButton)
    $form.Controls.Add($actions)
    $form.AcceptButton=$installButton;$form.CancelButton=$cancelButton;$form.ActiveControl=$portBox
    return [PSCustomObject]@{Form=$form;FieldsPanel=$grid;Port=$portBox;Lan=$lanBox;Username=$nameBox;Password=$passwordBox;Confirm=$confirmBox;Install=$installButton;Cancel=$cancelButton;Application=$applicationBox;Data=$dataBox;Https=$httpsBox;Hostname=$hostBox;Certificate=$certificateBox;CertificatePassword=$certificatePassword}
}
