### Version 2.1 ###
Function Start-ModbusPlugplay
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline,Mandatory)]$Stores,
        [Parameter()]$PurchasingCSV,
        [Parameter()]$MeterCSV<#,
        [Parameter()][switch]$WaitForJobs#>
    )
    $Stores = $Stores | Sort-Object | Get-Unique
    $file = Get-Item "$HOME\Modbus\$(Get-Date -Format M_d)_Modbus.txt" -ErrorAction SilentlyContinue
    #$jsonfile = Get-Item "$HOME\Modbus\$(Get-Date -Format M_d)_Modbus.json" -ErrorAction SilentlyContinue
    $data = [ordered]@{}
    if (!$file)
    {
        $file = New-Item "$HOME\Modbus\$(Get-Date -Format M_d)_Modbus.txt" -Force
        #$jsonfile = New-Item "$HOME\Modbus\$(Get-Date -Format M_d)_Modbus.json" -Force
        Write-Verbose "New output file created"
    }

    try{
        Write-Verbose "Preparing CSV's..."

        if (!$PurchasingCSV) {
            $PD = Get-ModbusFiles -PurchaseDoc
        }
        else {
            $PD = Import-Csv $PurchasingCSV -ErrorAction Stop
        }

        if (!$MeterCSV) {
            $MD = Get-ModbusFiles -MetersProject
        }
        else {
            $MD = Import-Csv $MeterCSV -ErrorAction Stop
        }

        Write-Verbose "Complete!"
    }
    catch{"Unable to import CSV file(s): " + $_}

    $mtx = New-Object System.Threading.Mutex($false, "plugplaymodbus")
    [void]$mtx.waitone()



    $start = 0; $end = 10; $int = 10 # Pointer for sets of Jobs
    $breakflag = $false
    while (!$breakflag) {
        foreach ($s in $stores[$start..$end]) {
            Start-Job -Name "$s" -ScriptBlock {
                foreach ($i in 10..27) {
                    Get-Store $using:s -ems $i
                }
            } |Out-Null
        }
        #foreach ($s in $Stores){

        foreach ($s in $stores[$start..$end]) {
            $data["Store"]+=@{"$s"=$null}
            $SPO = $PD|? 'Legacy Store' -eq $s|select -ExpandProperty 'Purchasing Document'

            if ($SPO){
                "`n$s">>$file
                $data.Store["$s"]+=@{"PO"=$SPO}
                $test = Test-Connection (Get-Store $s -ip) -Count 1 -ErrorAction SilentlyContinue

                if ($test){
                    Write-Verbose "$s is online and has a Purchasing Document"
                    $Ports = ($MD|? 'store number' -eq $s).'port name'|? {$_ -ne ''}

                    if ($Ports -eq $null){
                        Write-Verbose "No port names found in meter doc. Getting EMS systems..."
                        $cache = @()
                        $Ports = Get-Job -Name "$s" | Receive-Job -Wait -AutoRemoveJob
                        $Ports = $Ports|? status -Match success|? ip -ne $null|? url -NotMatch "^ems11"
                        $Ports | % {$cache+=$_.url.split('.')[0]}
                        $Ports = $cache
                        Write-Verbose "Complete!"
                    }#if ports are blank

                    foreach ($ems in $Ports){
                            $ip = Get-Store $s -ems $ems.Substring($ems.length - 2) -ip

                            if ($ip){
                                Write-Verbose "Plugplayin $s for $ip at $ems"
                                Send-Pdsql $s ("update global set action='scan_modbus:{0}'" -f $ip)|Out-Null
                                "$ems`: Plugplayed">>$file
                                $data.Store["$s"]+=@{$ems=$ip}
                            }#if IP is true
                            else{
                                "$ems`: Failed">>$file
                                $data.Store["$s"]+="$ems`: Failed"
                            }

                    }#foreach ems
                }#if store is online
                else{
                    "$s`: Offline">>$file
                    $data.Store["$s"]="Offline"
                }

            } #if store in PD
            else {
                "`n$s`: No Purchase Document">>$file
                $data.Store["$s"]+=@{"PO"=$null}
            }
            if ($WaitForJob)
            {
                Wait-ModbusJobs $s
            }
            
        }#foreach stores
        $start = $end+1; $end+=$int
        if ($start -ge $stores.Count) {$breakflag = $true}
        Get-Job | Remove-Job -Force
    }#while false
    [void]$mtx.ReleaseMutex()
    #ConvertTo-Json -InputObject $data >> $jsonfile
    return $data
}

#Export-ModuleMember Start-ModbusPlugplay