function Send-ModbusPlugplayReport 
{
    try {$file = Get-Item "$HOME\Modbus\$(Get-Date -Format M_d)_Modbus.txt" -ErrorAction Stop}
    catch{"error: " + $_}

    $mtx = New-Object System.Threading.Mutex($false, "plugplaymodbus")
    [void]$mtx.waitone()

    $email = @{
    to = 'robert.lutrick@us.ims-evolve.com'
    from = 'robert.lutrick@walmart.com'
    smtpserver = 'mail.wal-mart.com'
    subject = "Modbus Plugplay Report" 
    body = "Hello,`nI've attached the Modbus plugplay report for today.`nThank you,`nRobert"
    attachment = $file
    }
    Send-MailMessage -To $email.to -From $email.from  -Subject $email.subject -body $email.body -SmtpServer $email.smtpserver -Attachments $email.attachment
    
    [void]$mtx.ReleaseMutex()
}
