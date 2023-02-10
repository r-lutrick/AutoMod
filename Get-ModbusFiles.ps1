Function Get-ModbusFiles
{
    [cmdletbinding()]
    Param(
    [Parameter()][switch]$PurchaseDoc = $false,
    [Parameter()][switch]$RedmineDoc = $false,
    [Parameter()][switch]$EnergyProjectDoc = $false,
    [Parameter()][switch]$MetersProject = $false
    )

    $files = Get-ChildItem -Path "$HOMEDRIVE\dwsuserdata$\$env:username" -Recurse

    if ($PurchaseDoc){
        try
        {
            $POdoc = Import-Csv $($files | ? name -Match "^IMS PO" | sort -Descending -Property CreationTime | select -First 1).FullName
            return $POdoc
        }
        catch
        {
            "Please download latest IMS PO status.csv file from https://imsevolve365.sharepoint.com/sites/IMSEvolveUS/Wiki/Shared%20Documents/Modbus%20and%20energy"
        }
    }
    if ($EnergyProjectDoc){
        try
        {
            $EPdoc = Import-Csv $($files | ? name -Match "^Energy_Projects" | sort -Descending -Property CreationTime | select -First 1).FullName
            return $EPdoc
        }
        catch
        {
            "Please download latest Energy_Projects.csv file from https://imsevolve365.sharepoint.com/sites/IMSEvolveUS/Wiki/Shared%20Documents/Modbus%20and%20energy"
        }
    }
    if ($MetersProject){
        try
        {
            $Meters = Import-Csv $($files | ? name -Match "^Meters" | sort -Descending -Property CreationTime | select -First 1).FullName
            return $Meters
        }
        catch
        {
            "Please download latest Energy_Projects.csv file from https://imsevolve365.sharepoint.com/sites/IMSEvolveUS/Wiki/Shared%20Documents/Modbus%20and%20energy"
        }
    }

    if ($RedmineDoc)
    {
        try
        {
            $RMdoc = Import-Csv $($files | ? name -Match "^Tasks" | sort -Descending -Property CreationTime | select -First 1).FullName
            return $RMdoc
        }
        catch
        {
            "Please download new modbus as Tasks.csv from https://support.ims-evolve.com/projects/86/issues?set_filter=1&f[status_id]==14"
        }
    }
}