
Param(        
    [parameter(HelpMessage="An array of filter strings to not display things not liked.")]
    [AllowEmptyCollection()]
    [alias("f")]
    [String[]]
    $Filter,
    [parameter(HelpMessage="language for display eg. en-US.")]
    [alias("l")]
    [ValidateSet("en-US","de-DE","de-CH")]
    [String]
    $Language,
    [parameter(HelpMessage="hide console window")]
    [switch]
    $HideConsole = $False
)
Import-Module -Name $PSScriptRoot\lib\Console
Import-Module -Name $PSScriptRoot\lib\TestKeys


if ( $HideConsole ) {
    Hide-Console
}

# Run as administrator if not started with it
if (-not (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Prompt the user to elevate the script
    $arguments = "& '" + $myInvocation.MyCommand.Definition + "'"
    Write-Host $($Filter -join ",")
    if ( $Filter.Count -gt 0 ) {
        $arguments += " -filter " + $($Filter -join ",")
    }
    if ( $Language -ne "" ) {
        $arguments += " -language " + $Language
    }
    if ( $HideConsole ) {
        $arguments += " -hideconsole"
    }
    Write-Debug "-----------------"
    Write-Debug $arguments
    Write-Debug "-----------------"
    Start-Process powershell -Verb runAs -ArgumentList $arguments
    exit
}
Remove-Variable  -Name bm*
Remove-Variable  -Name msgTable
cls

$Lang=Get-SystemLanguage


if($Language -ne "") {
    Import-LocalizedData -BindingVariable msgTable -UICulture $Language
} else {
    try {
        Import-LocalizedData -BindingVariable msgTable -UICulture $Lang.ToString()
    } catch [ObjectNotFound] {
        Import-LocalizedData -BindingVariable msgTable -UICulture "en-US"
    }
}

# Write-Host $msgTable.Keys



Function Get-Boot-Entries {    
    $local:Configs = @() #Array contains the parsed objects
    $local:NameArray = @()
    $local:Pattern = '^(?<name>[a-zA-Z\-]*)?\s*(?<value>.*)?$'
    $local:enum    =  bcdedit /enum firmware 
    $local:Value   = ""
    $local:Name    = ""
    foreach ($item in $enum ){
        if ( $item.trim() ){
            $res = [regex]::matches( $item, $Pattern )				
		    if ( -not($item.contains( '----------------------------')) ) {			
			    if ( $res ){
				    $Value = $res[0].Groups['value'].value 
				    $Name  = $res[0].Groups['name'].value
				    if ( $Value ){
					    if ( $Name ){
						    $PSO = [PSCustomObject]@{
							    Name  = $Name
							    Value = $Value
						    }
						    $NameArray += $PSO
					    } else { # empty line means continues adding entries to the key                       
						    if ( $NameArray.count ){
							    ( $NameArray | Select-Object -last 1 ).Value += ";$Value"
						    }
					    }
				    }            
			    }
		     }
	    } else {
		    if ( $NameArray ){            
			    $local:Configs  += ,$NameArray
			    $NameArray = @()            
		    }
	    }
    }
    if ( $NameArray ){        
        $local:Configs  += ,$NameArray
    }
    $local:Configs    
}

function Calc-Boot-Order([Object[]]$Configs) {
    $local:hashBootEntries = @{}
    $local:displayorder = @('x')
    $local:id = ""
    $local:device = ""
    $local:description = ""
    $local:item = ""    
    foreach ( $item in $Configs ){
        $id = $item[1]    
        if ( $id.Value -eq '{fwbootmgr}' ) {
            $displayorder = $item | Where-Object {$_.Name -eq 'displayorder'}        
        } else {           
            $description = $item | Where-Object {$_.Name -eq 'description'}
            $device = $item | Where-Object {$_.Name -eq 'device'}
            $id = $item[1]
            if ( $id.Value -match "^{.*}$" -eq $false) {            
                $id = $item[0]
            }        
            $hashBootEntries.add($id.Value.Trim(),$description.Value)
         }
         # $item | Format-Table         
    }
    $local:bootOrder = $displayorder.Value -split ";"
    @($local:bootOrder,$local:hashBootEntries)
}


$local:Configs = Get-Boot-Entries
$local:bootOrder, $local:hashBootEntries = Calc-Boot-Order($local:Configs)

# --------------------- Start Formular -----------------------------

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Erstellen einer Tabelle mit einer Checkbox-Spalte
$bmBootManagerGrid = New-Object System.Windows.Forms.DataGridView

$bmBootManagerGrid.AutoSize = $true
$bmBootManagerGrid.AutoSizeColumnsMode = 'AllCells'

$bmBootManagerGrid.DefaultCellStyle.SelectionBackColor = [System.Drawing.Color]::White
$bmBootManagerGrid.DefaultCellStyle.SelectionForeColor = [System.Drawing.Color]::Black
$bmBootManagerGrid.SelectionMode = [System.Windows.Forms.DataGridViewSelectionMode]::FullRowSelect
$bmBootManagerGrid.DataGridViewCellStyle

$bmBootManagerGrid.RowsDefaultCellStyle.BackColor = [System.Drawing.Color]::DarkBlue
$bmBootManagerGrid.RowsDefaultCellStyle.ForeColor = [System.Drawing.Color]::White
$bmBootManagerGrid.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::LightBlue
$bmBootManagerGrid.AlternatingRowsDefaultCellStyle.ForeColor = [System.Drawing.Color]::Black


$bmDefaultBoot = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$bmNextBoot    = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
$bmText        = New-Object System.Windows.Forms.DataGridViewTextboxColumn
$bmHiddenText  = New-Object System.Windows.Forms.DataGridViewTextboxColumn



$bmNextBoot.HeaderText = $msgTable.colDextBootHeaderText
$bmDefaultBoot.HeaderText = $msgTable.colDefaultBootHeaderText
$bmText.HeaderText =  $msgTable.colNameHeaderText 
$bmHiddenText.HeaderText = $msgTable.colHiddenHeaderText

$bmBootManagerGrid.MultiSelect = $False
$bmBootManagerGrid.Width = 700

$bmBootManagerGrid.Columns.Add($bmNextBoot) | Out-Null
$bmBootManagerGrid.Columns.Add($bmDefaultBoot) | Out-Null
$bmBootManagerGrid.Columns.Add($bmText) | Out-Null
$bmBootManagerGrid.Columns.Add($bmHiddenText) | Out-Null


$bmX = 1
foreach( $bootId in $bootOrder ) {    
    '-' + $bootId + " / " + $hashBootEntries[$bootId]
    $bmEntryArry=@()
    if( $hashBootEntries[$bootId] ) {
        if ($bmX -eq 1) {
            $bmEntryArry=@($false,$true,$hashBootEntries[$bootId], $bootId)            
        } else {
            $bmEntryArry=@($false,$false,$hashBootEntries[$bootId], $bootId)            
        }
        if($Filter.Count -gt 0) {
            foreach($f in $Filter) { 
                $mex = "*$f*"                
                if($hashBootEntries[$bootId] -like $mex) {
                    [void]$bmBootManagerGrid.Rows.Add($bmEntryArry)
                    break
                }
            }
        } else {
            [void]$bmBootManagerGrid.Rows.Add($bmEntryArry)
        }
        $bmX += 1
    }
}

# $bmBootManagerGrid.ReadOnly = $true
$bmBootManagerGrid.AllowUserToAddRows = $false 
$bmBootManagerGrid.AllowUserToDeleteRows = $false

# Name and id we don't need to edit.
$bmBootManagerGrid.Columns[2].ReadOnly = $true
$bmBootManagerGrid.Columns[3].ReadOnly = $true
# we add the index bootID bit we don't like to show it.
$bmBootManagerGrid.Columns[3].Visible = $False

# Set this to empty on OK We evaluate and set them
$script:bmNextBootName=""
$script:bmDefaultBootName=""


# Ereignisbehandlung für Checkbox-Änderungen
$bmBootManagerGrid.Add_CellContentClick({
    $columnIndex = $_.ColumnIndex
    $rowIndex = $_.RowIndex    
    $cell = $bmBootManagerGrid.Rows[$_.rowIndex].Cells[$_.columnIndex]    
    if($rowIndex -eq -1) {
        Write-Host "Ignore Header click"
        return
    }
    if ($columnIndex -eq 1) {        
        if ($cell.Value -ne $true) {
            for($i=0; $i -lt $bmBootManagerGrid.RowCount;$i++) {
                if( $_.rowIndex -ne $i) {
                    $bmBootManagerGrid.Rows[$i].Cells[$columnIndex].Value = $false
                } else {
                    $cell.Value=$true
                    $script:bmDefaultBootName = $bmBootManagerGrid.Rows[$_.rowIndex].Cells[3].Value
                }
            }            
            Write-Host "Default boot wurde $($rowIndex + 1) aktiviert."
        } else {
            # Validate at least one need to be the default
            Write-Host "Default boot wurde $($rowIndex + 1) deaktiviert."
            $cell.Value=$false
            $bmDefaultBoot = ""
            $allFalse = $true
            for($i=0; $i -lt $bmBootManagerGrid.RowCount;$i++) {
                if($bmBootManagerGrid.Rows[$i].Cells[$columnIndex].Value -eq $true) {
                    $allFalse = $false
                }
            }
            if( $allFalse -eq $true ) {
                $cell.Value = $true
                $script:bmDefaultBootName =""
            }
        }
    }
    if ($columnIndex -eq 0) {
        if ($cell.Value -ne $true) {
            Write-Host "Next Boot wurde $($rowIndex + 1) aktiviert!"
            for($i=0; $i -lt $bmBootManagerGrid.RowCount;$i++) {
                if( $_.rowIndex -ne $i) {           
                    $bmBootManagerGrid.Rows[$i].Cells[$columnIndex].Value = $false
                }
            }
            $cell.Value=$true
            $script:bmNextBootName = $bmBootManagerGrid.Rows[$_.rowIndex].Cells[3].Value
        } else {
            Write-Host "Next boot wurde $($rowIndex + 1) deaktiviert."
            $cell.Value=$false
            $script:bmNextBootName = ""
        }
    }
})

# OK- und Abbrechen-Buttons hinzufügen
$bmOkButton = New-Object System.Windows.Forms.Button
$bmOkButton.Text = $msgTable.tOKText
$bmOkButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$bmOkButton.Location = New-Object System.Drawing.Point(50, 200)
$bmOkButton.Size = New-Object System.Drawing.Size(100, 23)

$bmCancelButton = New-Object System.Windows.Forms.Button
$bmCancelButton.Text = $msgTable.tAbortText
$bmCancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$bmCancelButton.Location = New-Object System.Drawing.Point(150, 200)
$bmCancelButton.Size = New-Object System.Drawing.Size(100, 23)

# Anzeigen der Tabelle und der Buttons
$bmForm = New-Object System.Windows.Forms.Form
$bmForm.Text = "EFI Boot Manager"


$img = [System.Drawing.Image]::Fromfile("$PSScriptRoot\chooseEFIBoot.png")
$intPtr = New-Object IntPtr
$thumbnail = $img.GetThumbnailImage(72, 72, $null, $intPtr)
$bitmap = New-Object Drawing.Bitmap $thumbnail
$bitmap.SetResolution(72, 72)
$icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon());
$bmForm.Icon = $icon


# $bmForm.Size = New-Object System.Drawing.Size(350, 240)

$bmForm.ClientSize = New-Object System.Drawing.Size(300, 240)

$bmForm.Controls.Add($bmBootManagerGrid)
$bmForm.Controls.Add($bmOkButton)
$bmForm.Controls.Add($bmCancelButton)
$bmForm.AcceptButton = $bmOkButton
$bmForm.CancelButton = $bmCancelButton

# Button-Ereignisbehandlung zum SchlieÃŸen des Fensters und Beenden des Programms
$bmOkButton.Add_Click({
    Write-Debug "Ok Click"
    $bmForm.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $bmForm.Close()
})
$bmCancelButton.Add_Click({
    Write-Debug "Cancel Click"
    $bmForm.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bmForm.Close()
})


# Überprüfen des Ergebnisses der Dialogschleife

# $bmForm.Width = 700
$CenterScreen = [System.Windows.Forms.FormStartPosition]::CenterScreen;
$bmForm.StartPosition = $CenterScreen;


$bmBootManagerGrid.AllowuserToResizeRows = $False
$bmBootManagerGrid.ScrollBars = 0

function recalcSize {
    Param(        
        [parameter(HelpMessage="Init first")]
        [switch]
        $Init = $False
    )
 
    if ($Init) {
        # Start calculate size
        $bmForm.Width = $bmBootManagerGrid.Width
        $bmSumGridHeight = 0
        for($i=-1;$i -lt $bmBootManagerGrid.RowCount;$i++) {
            $bmSumGridHeight += $bmBootManagerGrid.Rows[$i].Height
        }

        $bmBootManagerGrid.AutoSize = $False        
        $bmBootManagerGrid.Height = $bmSumGridHeight

        $bmForm.Height = $bmBootManagerGrid.Height + 80

    } else {
        $bmBootManagerGrid.Height = $bmForm.Height - 80
    }
    $cellHeight = ($bmBootManagerGrid.Height - $bmBootManagerGrid.ColumnHeadersHeight) / ( $bmBootManagerGrid.RowCount)
    $fontSize = $bmBootManagerGrid.DefaultCellStyle.Font.Size
    $newFontSize = $cellHeight - ($cellHeight / 1.8)

    # Write-Host $bmBootManagerGrid.DefaultCellStyle.Font.Size
    # Write-Host "New Font Height should be $cellHeight"

    $newFont = New-Object System.Drawing.Font($bmBootManagerGrid.DefaultCellStyle.Font.FontFamily,$newFontSize,$bmBootManagerGrid.DefaultCellStyle.Font.Style)    
    $newHeaderFont = New-Object System.Drawing.Font($bmBootManagerGrid.ColumnHeadersDefaultCellStyle.Font.FontFamily,
                                                    $newFontSize,
                                                    $bmBootManagerGrid.ColumnHeadersDefaultCellStyle.Font.Style)    
    $bmBootManagerGrid.DefaultCellStyle.Font = $newFont    

    $bmBootManagerGrid.ColumnHeadersDefaultCellStyle.Font = $newHeaderFont   
    $bmBootManagerGrid.ColumnHeadersHeight = $cellHeight

    
    for($i=0;$i -lt $bmBootManagerGrid.RowCount;$i++) {
        $bmBootManagerGrid.Rows[$i].Height = $cellHeight
    }
    # Calculate new Width
    $resizeTo=0
    for($i=0;$i -lt $bmBootManagerGrid.ColumnCount;$i++) {        
        $resizeTo += $bmBootManagerGrid.Rows[0].Cells[$i].Size.Width
    }   
    $bmBootManagerGrid.Width = $resizeTo
    $bmForm.Width = $resizeTo

    $bmOkButton.Left = $bmForm.Width - ( $bmOkButton.Width + 30 )
    $bmCancelButton.Left = $bmOkButton.Left - ( $bmCancelButton.Width + 10 )
    $bmOkButton.Top = $bmBootManagerGrid.Height + 5
    $bmCancelButton.Top = $bmBootManagerGrid.Height + 5    
}


$bmForm.Add_MouseWheel({
    Param(
        [Object]$sender,
        [System.Windows.Forms.MouseEventArgs]$e
    )
    $local:zoom = Test-CtrlKey 
    if( $local:zoom ) {
        if ($e.Delta -gt 0) {            
           $bmForm.Height += 10
        } else {
            $bmForm.Height -= 10
        }
    }    
})


recalcSize -Init

$bmForm.Add_Shown({
    $bmForm.Activate()
})

$bmForm.Add_Resize({
    recalcSize
})


$bmForm.ShowDialog() | Out-Null

# Show-Console

## evaluate the pressed button on exit.

if ($bmForm.DialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Host $msgTable.msgOkPressed
    Write-Host "---------------------"
    Write-Host $bmNextBootName
    Write-Host "---------------------"
    Write-Host "---------------------"
    Write-Host $bmDefaultBootName
    Write-Host "---------------------"

    $bcdexe = Get-Command "bcdedit"

    Write-Host $bcdexe.Source

    if($bmNextBootName -ne "") {
        Write-Host "We set the Next Boot now"        
        Start-Process -NoNewWindow -FilePath $bcdexe.Source -ArgumentList "/set","{fwbootmgr}","bootsequence","$bmNextBootName"        
    }
    if($bmDefaultBootName -ne "") {
        Write-Host "We set the default Boot now $bmDefaultBoot $bmDefaultBoot[$bmDefaultBoot]"     
        Start-Process -NoNewWindow -FilePath $bcdexe.Source -ArgumentList "/set","{fwbootmgr}","displayorder","$bmDefaultBoot","/addfirst"
    }
      
} else {
    Write-Host $msgTable.msgAbortPressed
}


if ($bmForm.DialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
    # -----
    # Start Boot reboot dialog

    $bmRForm = New-Object System.Windows.Forms.Form
    $bmRForm.Icon = $icon
    $bmRForm.Text = "Start"
    $bmRForm.Size = "400,100"

    # OK- und Abbrechen-Buttons hinzufügen
    $bmrOkButton = New-Object System.Windows.Forms.Button
    $bmrOkButton.Text = $msgTable.tRebootText
    $bmrOkButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $bmrOkButton.Location = New-Object System.Drawing.Point(10, 10)
    $bmrOkButton.Size = New-Object System.Drawing.Size(75, 23)

    $bmrShutdownButton = New-Object System.Windows.Forms.Button
    $bmrShutdownButton.Text = $msgTable.tShutdownText
    $bmrShutdownButton.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $bmrShutdownButton.Location = New-Object System.Drawing.Point(110, 10)
    $bmrShutdownButton.Size = New-Object System.Drawing.Size(75, 23)

    $bmrCancelButton = New-Object System.Windows.Forms.Button
    $bmrCancelButton.Text = $msgTable.tAbortText
    $bmrCancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bmrCancelButton.Location = New-Object System.Drawing.Point(220, 10)
    $bmrCancelButton.Size = New-Object System.Drawing.Size(75, 23)

    $bmrForm.Controls.Add($bmrOkButton)
    $bmrForm.Controls.Add($bmrShutdownButton)
    $bmrForm.Controls.Add($bmrCancelButton)
    $bmrForm.AcceptButton = $bmrOkButton
    $bmrForm.CancelButton = $bmrCancelButton


    $bmrForm.StartPosition = $CenterScreen;

    $bmrForm.Add_Shown({
        $bmrForm.Activate()
        if ( $HideConsole ) {
            Hide-Console
        }
    })

    $bmrForm.ShowDialog() | Out-Null    

    if ($bmrForm.DialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        Write-Host $msgTable.msgReboot
        Restart-Computer -Force
    } elseif ( $bmrForm.DialogResult -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Host $msgTable.msgShutdown
        Stop-Computer -Force
    } else {
        Write-Host $msgTable.msgNoAction
    }
}