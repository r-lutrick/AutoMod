function Get-EVData
{
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        $data,

        [Parameter()]
        $o = $false,
        
        [Parameter()]
        [switch]$v = $false
    )
    $POdoc = Get-ModbusFiles -PurchaseDoc
    $output = @()
    $i = 0

    if (!$o)
    {
        $v=$true
    }

    foreach ($t in $data)
    {
        Write-Verbose "entered loop"
        $obj = New-Object psobject
        $s = $t.subject.split(' ')[0]
        
        if($s -match '^[0-9]')
        {
            if (Get-Store $s| ? status -Match success)
            {
                Write-Verbose "Store checks out"
                $data = [ordered]@{ "STORE"=$s
                                    "REDMINE"=$t.id
                                    "PURCHASE"=$($POdoc|? 'legacy store' -eq $s).'Purchasing document'
                                    "DENT_PS12HD"=0
                                    "DENT_PS48HD"=0}
                $dc = Get-DentCount $s

                if ($dc)
                {
                    Write-Verbose "Dent count true"
                    $dc |% {$data[$_.Name]=$_.Count}
                }

                foreach ($k in $data.Keys)
                {
                    Write-Verbose "gathering data for object"
                    Add-Member -InputObject $obj -MemberType NoteProperty -Name $k -Value $data.$k
                }
                $output+=$obj

                Write-Verbose "output completed"
            }
            else {Add-Member -InputObject $obj -MemberType NoteProperty -Name "STORE" -Value "$s OFFLINE"; $output+=$obj}

            if ($v)
            {
                Write-Verbose "view true"
                $output[$i]
                $i++
            }
        }
    }

    if ($o)
    {
        $mtx = New-Object System.Threading.Mutex($false, "getevdata")
        [void]$mtx.waitone();
        $output |ConvertTo-Csv -NoTypeInformation |Add-Content -Path $o
        [void]$mtx.ReleaseMutex()
    }
}

Export-ModuleMember Get-EVData