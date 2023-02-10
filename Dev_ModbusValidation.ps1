Function Start-ModbusPlugplay
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline,Mandatory)]$Stores,
        [Parameter()]$PurchasingCSV,
        [Parameter()]$MeterCSV,
        [Parameter()][switch]$WaitForJobs
    )
    $Stores = $Stores | Sort-Object | Get-Unique
    $file = Get-Item "$HOME\Modbus\$(Get-Date -Format M_d)_Modbus.txt" -ErrorAction SilentlyContinue
    $data = @{}
    if (!$file)
    {
        $file = New-Item "$HOME\Modbus\$(Get-Date -Format M_d)_Modbus.txt" -Force
        Write-Verbose "New output file created"
    }

    try
    {
        Write-Verbose "Preparing CSV's..."
        if (!$PurchasingCSV){
            $PD = Get-ModbusFiles -PurchaseDoc
        }
        else {$PD = Import-Csv $PurchasingCSV -ErrorAction Stop}

        if (!$MeterCSV){
            $MD = Get-ModbusFiles -MetersProject
        }
        else{$MD = Import-Csv $MeterCSV -ErrorAction Stop}

        Write-Verbose "Complete!"
    }
    catch{"Unable to import CSV file(s): " + $_}

    $mtx = New-Object System.Threading.Mutex($false, "plugplaymodbus")
    [void]$mtx.waitone()

    foreach ($s in $Stores)
    {
        $PO = ($PD|? 'Legacy Store' -eq $s).'Purchasing Document'
        $test = Test-Connection (Get-Store $s -ip) -Count 1 -ErrorAction SilentlyContinue

        if ($PO -and $test)
        {
            "`n$s">>$file
            $Managers = Send-Pdsql $s "select id,owner from manager"
            $Ports = ($MD|? 'store number' -eq $s).'port name'|? {$_ -ne ''}

            if ($Ports -eq $null)
            {
                Write-Verbose "No port names found in meter doc. Getting EMS systems..."

                $cache = @()
                $Ports = 10..27|% {Get-Store $s -ems $_|? status -Match success|? ip -ne $null|? url -NotMatch "^ems11"}
                $Ports | % {$cache+=$_.url.split('.')[0]}
                $Ports = $cache

                Write-Verbose "Complete!"
            }#if ports are blank

            foreach ($ems in $Ports)
            {
                    $ip = Get-Store $s -ems $ems.Substring($ems.length - 2) -ip

                    if ($ip)
                    {
                        $d = $Managers|? id -Match (($ip.split('.')|% {$_.padleft(3,'0')}) -join '_')

                        if (!$d){
                            Write-Verbose "Plugplayin $s for $ip at $ems"

                            Send-Pdsql $s ("update global set action='scan_modbus:{0}'" -f $ip)|Out-Null
                            "$ems`: Plugplayed">>$file
                            $data[$s]+=@{$ems=$ip}
                        }
                        else{"$ems in Daemon already">>$file}

                    }#if IP is true
                    else{"$ems`: Failed">>$file}

            }#foreach ems
        }#if store has PO and Online
        if ($WaitForJob)
        {
            Wait-ModbusJobs $s
        }

    }#foreach stores
    [void]$mtx.ReleaseMutex()
    return $data
}
