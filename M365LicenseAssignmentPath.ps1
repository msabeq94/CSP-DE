
Connect-MgGraph -Scopes "User.Read.All","AuditLog.read.All"  -NoWelcome
Function Convert-FrndlyName {
    param(
        [Parameter(Mandatory=$true)]
        [Array]$InputIds
    )
    $EasyName = $FriendlyNameHash[$SkuName]
   if(!($EasyName))
   {$NamePrint = $SkuName}
   else
   {$NamePrint = $EasyName}
   return $NamePrint
}
Connect_MgGraph
$Location=Get-Location
$ExportCSV="$Location\M365Users_LicenseAssignmentPath_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$ExportResult=""   
$ExportResults=@() 
$PrintedUser=0 

#Get license in the organization and saving it as hash table
$SKUHashtable=@{}
Get-MgBetaSubscribedSku –All | foreach{
 $SKUHashtable[$_.skuid]=$_.Skupartnumber
}
#Get friendly name of Subscription plan from external file
$FriendlyNameHash=Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction Stop | ConvertFrom-StringData
#Get friendly name of Service plan from external file
$ServicePlanHash=@{}
Import-Csv -Path .\ServicePlansFrndlyName.csv | ForEach-Object {
 $ServicePlanHash[$_.ServicePlanId] = $_.ServicePlanFriendlyNames
}

$GroupNameHash=@{}
#Process users
$RequiredProperties=@('UserPrincipalName','DisplayName','EmployeeId','CreatedDateTime','AccountEnabled','Department','JobTitle','LicenseAssignmentStates','AssignedLicenses','SigninActivity')
Get-MgBetaUser -All -Property $RequiredProperties | select $RequiredProperties | ForEach-Object {
 $Count++
 $Print=1
 $DirectlyAssignedLicense=@()
 $GroupBasedLicense=@()
 $DirectlyAssignedLicense_FrndlyName=@()
 $GroupBasedLicense_FrndlyName=@()
 $UPN=$_.UserPrincipalName
 Write-Progress -Activity "`n     Processing user: $Count - $UPN"
 $DisplayName=$_.DisplayName
 $AccountEnabled=$_.AccountEnabled
 $LicenseAssignmentStates=$_.LicenseAssignmentStates

 if($AccountEnabled -eq $true)
 {
  $AccountStatus='Enabled'
 }
 else
 {
  $AccountStatus='Disabled'
 }

 foreach($License in $licenseAssignmentStates)
 { 
  $SkuName=$SkuHashtable[$License.SkuId]
  $FriendlyName=Convert-FrndlyName -InputIds $SkuName
  $DisabledPlans=$License.DisabledPlans
  $ServicePlanNames=@()
  if($DisabledPlans.count -ne 0 )
  {
   foreach($DisabledPlan in $DisabledPlans)
   {
    $ServicePlanName = $ServicePlanHash[$DisabledPlan]
    if(!($ServicePlanName))
    {$NamePrint = $DisabledPlan}
    else
    {$NamePrint = $ServicePlanName}
    $ServicePlanNames += $NamePrint
   }
  }
  $DisabledPlans=$ServicePlanNames -join ","
  $State=$License.State
  $Errors=$License.Error
 
  #Filter for users with license assignment errors
  if($FindUsersWithLicenseAssignmentErrors.IsPresent -and ($State -eq "Active"))
  {
   $Print=0
  }

  if($License.AssignedByGroup -eq $null)
  {
   $LicenseAssignmentPath="Directly assigned"
   $GroupName="NA"
   #Filter for group based license assignment
   if($ShowGrpBasedLicenses.IsPresent)
   {
    $Print=0
   }
  }
  else
  {
   $LicenseAssignmentPath="Inherited from group"

   #Filter for directly assigned licenses
   if($ShowDirectlyAssignedLicenses.IsPresent)
   {
    $Print=0
   }

   $AssignedByGroup=$License.AssignedByGroup
   # Check Id-Name pair already exist in hash table
   if($GroupNameHash.ContainsKey($AssignedByGroup))
   {
    $GroupName=$GroupNameHash[$AssignedByGroup]
   }
   else
   {
    $GroupName=(Get-MgBetagroup -GroupId $AssignedByGroup).DisplayName
    $GroupNameHash[$AssignedByGroup]=$GroupName
   }
  }
  if($Print -eq 1)
  {
   $ExportResult=[PSCustomObject]@{'Display Name'=$DisplayName;'UPN'=$UPN;'License Assignment Path'=$LicenseAssignmentPath;'Sku Name'=$SkuName;'Sku_FriendlyName'=$FriendlyName;'Disabled Plans'=$DisabledPlans;'Assigned via(group name)'=$GroupName;'State'=$State;'Error'=$Errors;'Account Status'=$AccountStatus}
   $ExportResult | Export-Csv -Path $ExportCSV -Notype -Append
  }
 }
}
Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed

Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 