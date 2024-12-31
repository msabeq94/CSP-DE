Connect-MgGraph -Scopes "User.Read.All"  -NoWelcome

$Location=Get-Location
$ExportCSV="$Location\UnlicensedUsers_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$ExportResult=""   
$ExportResults=@()  


$Count=0
$PrintedUser=0
#retrieve users
$RequiredProperties=@('UserPrincipalName','CreatedDateTime','AccountEnabled','Department','JobTitle','UserType')
Get-MgBetaUser -Filter 'assignedLicenses/$count eq 0' -ConsistencyLevel eventual -CountVariable unlicensedUserCount -All -Property $RequiredProperties | select $RequiredProperties | ForEach-Object {
 $Count++
 $UPN=$_.UserPrincipalName
 Write-Progress -Activity "`n     Processed user: $Count - $UPN"
 $CreatedDate=$_.CreatedDateTime
 $AccountEnabled=$_.AccountEnabled
 $Dept=$_.Department
 $Title=$_.JobTitle
 $UserType=$_.UserType

 if($AccountEnabled -eq $true)
 {
  $AccountStatus='Enabled'
 }
 else
 {
  $AccountStatus='Disabled'
 }

 

 #Inactive days based on interactive signins filter
 if(!($IncludeDisabledUsers.IsPresent) -and ($AccountStatus -eq 'Disabled'))
 {
  return
 }

 if(($ExcludeGuests.IsPresent) -and ($UserType -eq 'Guest'))
 {
  return
 }
    
 if(($Department -ne "") -and ($Department -ne $Dept))
 {
  return
 }

 If(($JobTitle -ne "") -and ($Title -ne $JobTitle))
 {
  return
 }

 #Export users to output file
  
 $PrintedUser++
 $ExportResult=[PSCustomObject]@{'UPN'=$UPN;'Department'=$Dept;'Job Title'=$Title;'Creation Time'=$CreatedDate;'User Type'=$UserType;'Account Status'=$AccountStatus;}
 $ExportResult | Export-Csv -Path $ExportCSV -Notype -Append
 
}

Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed
Write-Host  "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" 

