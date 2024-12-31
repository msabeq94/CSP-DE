Connect-AzAccount
$AADToken =  ConvertTo-SecureString -AsPlainText  (Get-AzAccessToken -ResourceTypeName MSGraph).token -Force
Start-Sleep -Seconds 5
Connect-MgGraph -AccessToken $AADToken

$users  =  Import-Csv "C:\Users\msabek\OneDrive - mos94\Projects\CSP-DE\users.csv"  | Where-Object {$_ -ne $null -and $_ -ne ""}

foreach ($user in $users) {
    Remove-MgUser -UserId $user.ID  -Confirm:$false
    Write-Host "User $($user.name) deleted"
}
