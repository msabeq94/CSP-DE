
Connect-MgGraph -Scopes "Directory.Read.All"  -ErrorAction SilentlyContinue -Errorvariable ConnectionError |Out-Null

$Result=""   
$GuestCount=0
$PrintedGuests=0

#Output file declaration 
$ExportCSV=".\GuestUserReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
#Getting guest users
Get-MgBetaUser -All -Filter "UserType eq 'Guest'" -ExpandProperty MemberOf  | foreach {
    $DisplayName = $_.DisplayName
    $GuestCount++
    Write-Progress -Activity "Processed mailbox count: $GuestCount  Currently Processing: $DisplayName"
    $AccountAge = (New-TimeSpan -Start $_.CreatedDateTime).Days

    $Company = $_.CompanyName
    if($Company -eq $null)
    {
        $Company = "-"
    }
    $GroupMembership = @($_.MemberOf.AdditionalProperties.displayName) -join ','
    if($GroupMembership -eq $null)
    {
        $GroupMembership = '-'
    }
    #Export result to CSV file 
    $PrintedGuests++
    $Result = [PSCustomObject] @{'DisplayName'=$DisplayName;'UserPrincipalName'=$_.UserPrincipalName;'Company'=$Company;'EmailAddress'=$_.Mail;'CreationTime'=$_.CreatedDateTime ;'AccountAge(days)'=$AccountAge;'CreationType'=$_.CreationType;'InvitationAccepted'=$_.ExternalUserState;'GroupMembership'=$GroupMembership} 
    $Result | Export-Csv -Path $ExportCSV -Notype -Append
}

if((Test-Path -Path $ExportCSV) -eq "True")
{
   
    Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 
    Write-Host `nThe Output file contains $PrintedGuests guest users.
}
else
{
    Write-Host "No guest user found"
}
Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed

