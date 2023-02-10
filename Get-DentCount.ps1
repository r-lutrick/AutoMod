function Get-DentCount ($store)
{
    $output=@()
    $managers = send-pdsql $store "select id,owner from manager"
    $dents = $managers |? owner -Match dent
    if ($dents)
    {
        $unique_dents = $dents.id.substring(1,15)|select -Unique

        foreach ($u in $unique_dents)
        {
	        $output += ($dents |? id -Match $u |select -First 1)
        }
    }
    return ($output |group -Property owner -NoElement)
}
Export-ModuleMember Get-DentCount