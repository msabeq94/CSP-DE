
Connect-MgGraph -Scopes "Application.Read.All" -ErrorAction SilentlyContinue -Errorvariable ConnectionError |Out-Null
Write-Host "Microsoft Graph Beta Powershell module is connected successfully" -ForegroundColor Green



$Location=Get-Location
$ExportCSV = "$Location\EnterpriseApps_and_their_Owners_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$PrintedCount=0
$Count=0
$TenantGUID= (Get-MgOrganization).Id


$RequiredProperties=@('DisplayName','AccountEnabled','Id','SigninAudience','Tags','AppRoleAssignmentRequired','ServicePrincipalType','AdditionalProperties','AppDisplayName')
Get-MgServicePrincipal -All | foreach {
 $Print=1
 $Count++
 $EnterpriseAppName=$_.DisplayName
 $UserSigninStatus=$_.AccountEnabled
  Write-Progress -Activity "Processed enterprise apps: $Count - $EnterpriseAppName "
 $Id=$_.Id
 $Tags=$_.Tags
 if($Tags -contains "HideApp")
 {
  $UserVisibility="Hidden"
 }
 else
 {
  $UserVisibility="Visible"
 }
 $IsRoleAssignmentRequired=$_.AppRoleAssignmentRequired
 if($IsRoleAssignmentRequired -eq $true)
 {
  $AccessScope="Only assigned users can access"
 }
 else
 {
  $AccessScope="All users can access"
 }
 [DateTime]$CreationTime=($_.AdditionalProperties.createdDateTime)
 $CreationTime=$CreationTime.ToLocalTime()
 $ServicePrincipalType=$_.ServicePrincipalType
 $AppRegistrationName=$_.AppDisplayName
 $AppOwnerOrgId=$_.AppOwnerOrganizationId
 if($AppOwnerOrgId -eq $TenantGUID)
 {
  $AppOrigin="Home tenant"
 }
 else
 {
  $AppOrigin="External tenant"
 }
 $Owners=(Get-MgServicePrincipalOwner -ServicePrincipalId $Id).AdditionalProperties.userPrincipalName
 $Owners=$Owners -join ","
 if($owners -eq "")
 {
  $Owners="-"
 }


 
   $PrintedCount++
   $ExportResult=[PSCustomObject]@{'Enterprise App Name'=$EnterpriseAppName;'App Id'=$Id;'App Owners'=$Owners;'App Creation Time'=$CreationTime;'User Signin Allowed'=$UserSigninStatus;'User Visibility'=$UserVisibility;'Role Assignment Required'=$AccessScope;'Service Principal Type'=$ServicePrincipalType;'App Registration Name'=$AppRegistrationName;'App Origin'=$AppOrigin;'App Org Id'=$AppOwnerOrgId}
   $ExportResult | Export-Csv -Path $ExportCSV -Notype -Append
  
}

Write-Progress -Activity "Exporting data to CSV" -Status "Completed" -Completed

Write-Host `nThe script processed $Count enterprise apps and the output file contains $PrintedCount records.  
Write-Host `n The Output file available in: -NoNewline -ForegroundColor Yellow ;Write-Host "$ExportCSV"  `n

   