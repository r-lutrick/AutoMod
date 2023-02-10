### Version 1.1 ###
function Get-ModbusValidation
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline,Mandatory)]
        $stores,

        [Parameter()]
        $o = $false,

        [Parameter()][switch]
        $v = $false,

        [Parameter()][switch]
        $autoplugplay = $false,

        [Parameter()][switch]
        $sendemail = $false
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $POdoc = Get-ModbusFiles -PurchaseDoc -ErrorAction Stop
    $EProject = Get-ModbusFiles -EnergyProjectDoc -ErrorAction Stop
    $output = @() #prepare output
    $header = @("Store", "PO","Dents","Online","Attempted","Offline")

    if (!$o)
    {
        $v = $true
    }

    foreach ($s in $stores)
    {
        Start-Job -Name "$s ems" -ScriptBlock {
            foreach ($i in 10..27){Get-Store $using:s -ems $i|? status -Match success|? url -NotMatch ems11|? ip -NE $null}
        }|Out-Null
    }
    
    foreach ($s in $stores)
    {
        Get-Job -Name "$s ems" |Receive-Job -Wait -OutVariable $s`_ems -AutoRemoveJob -ErrorAction SilentlyContinue |Out-Null
        $temp = $(Get-Variable -Name $s`_ems).Value
        $PO = $($POdoc |? 'legacy store' -eq $s).'Purchasing Document'
        $IPS = @($temp.ip) #ip address'
        $EMS = @() #ems'
        $Attempted = @()
        foreach ($val in $temp.url){$EMS+=$val.split(".")[0]}
        [int]$TDP = 0 #total dents pulled
        [int]$TDE = 0 #total dents expected
        $SProject = $EProject|? 'Store Number' -eq $s|? 'Project Type' -eq 'Submetering Wired Full Store' #store project
        $m = Send-Pdsql $s "select id,owner from manager" #managers

        $TDE += ([int]$SProject.'actual ps48 count' + [int]$SProject.'actual ps12 count') #add total dents expected
        
        foreach ($IP in $IPS) #for each ip in list
        {
            try{$d = $m|? id -Match (($IP.split('.')|% {$_.padleft(3,'0')}) -join '_')} #get dent based on IP
            catch{"Error occured: $_"}
            if ($d |? owner -Match "DENT"|select -Unique)
            {
                $TDP++
            } #incrament Total Dents Pulled by 1 if there is a dent in the Daemon
            
            elseif($autoplugplay -and !($d|? owner -NotMatch "DENT"))
            {
                Send-Pdsql $s ("update global set action='scan_modbus:{0}'" -f $IP)|Out-Null
                $Attempted+=$IP
            } #plugplay for IP if it's online and not in the Daemon
        }
        if (!$Attempted){$Attempted=@(0)}
        else{$Attempted = $Attempted -join ', '}
        $PO = $PO -join ', '
        $EMS = $EMS -join ', '

        $cache = @("$PO","$TDP of $TDE","$EMS","$Attempted","All other EMS systems offline")
        $obj = New-Object psobject
        $i = 0
        Add-Member -InputObject $obj -MemberType NoteProperty -Name $header[$i] -Value $s
        foreach ($row in $cache)
        {
            $i++
            Add-Member -InputObject $obj -MemberType NoteProperty -Name $header[$i] -Value $row
        }
        $output+=$obj
    }
    $stopwatch.Stop()
    $time = [math]::Round($stopwatch.Elapsed.TotalSeconds,1)

    if($v)
    {
        $output
        "Total time elapsed: $time"
    }
    if($o)
    {
        $mtx = New-Object System.Threading.Mutex($false, "getmodbusvalidation")
        [void]$mtx.waitone();
        $output|ConvertTo-Csv -NoTypeInformation|Add-Content -Path $o
        [void]$mtx.ReleaseMutex()
    }
    if ($sendemail)
    {
        $email = @{
        to = 'uros.ivovic@ims-evolve.com','mike.chapman@us.ims-evolve.com','Geoffrey.Shook@walmart.com','robert.lutrick@us.ims-evolve.com'
        from = ''
        smtpserver = 'mail.wal-mart.com'
        subject = "Modbus Validation Report | $(Get-Date -Format M/d)"
        }
        Send-MailMessage -To $email.to -From $email.from  -Subject $email.subject -Body ($output|Out-String) -SmtpServer $email.smtpserver
    }
<#
.SYNOPSIS
Outputs Modbus Validation report

.DESCRIPTION
This will grab the needed information for displaying modbuss plugplay status.

.PARAMETER stores
Must specify one or more stores to validate

.PARAMETER o
This will output the data to a csv file.

.PARAMETER v
If parmater (o)utput is not specified (v)iew is autoatically set.

.PARAMETER autoplugplay
Autoplugplay will check if the ems system is pinging and if there is no manager currently in the Daemon. If no manager is present and the ems is online it will plugplay the daemon and attempt to pull in the Modbus Dent again.

.PARAMETER sendemail
Sends an email to Uros, Mike, Geoffrey and Robert of the output.

.EXAMPLE
Get-ModbusValidation -stores 69
.EXAMPLE
Get-ModbusValidation 69 -o .\filename.csv
.EXAMPLE
Get-ModbusValidation 69 -autoplugplay
.EXAMPLE
$stores = 69,96,1212
Get-ModbusValidation $stores
.EXAMPLE
$stores = 69,96,1212
Get-ModbusValidation $stores -autoplugplay
#>
}
Export-ModuleMember Get-ModbusValidation