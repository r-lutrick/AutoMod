Function Wait-ModbusJobs
{
    [CmdletBinding()]
    Param
    (
        [Parameter(ValueFromPipeline, Mandatory)]$Store
    )
    "Creating background job for store $s..."
    Start-Job -Name "$s Jobs" -ScriptBlock {
        $done = $false
        $timeout = 0
    
        while (!$done -or ($timeout -ge 16))
        {
            $plugplayjobs = Send-Pdsql $using:Store "select state,process job" |? process -eq "MODBUS_PLUGPLAY"
            $total = $plugplayjobs.count
            $completed = ($plugplayjobs|? state -NE 1).count
            if ($completed -eq $total)
            {
                Get-ModbusValidation $using:Store -autoplugplay -o ".\$(Get-Date -Format M_d)_ValidationReport.csv"
                break
            }
            $timeout++
            Start-Sleep -Seconds (60*30)
        }
    }
    "Complete! Job name: '$s Jobs'"
    "File .\$(Get-Date -Format M_d)_ValidationReport.csv will be created once job is finished"
}
Export-ModuleMember Wait-ModbusJobs