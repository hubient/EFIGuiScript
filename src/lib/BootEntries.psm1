function Get-BootEntries() {    
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

function Get-BootOrder() {
    Param(
        [Object[]]
        $Configs
    )
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