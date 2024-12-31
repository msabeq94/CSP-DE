Connect-MgGraph -Scopes "Directory.Read.All"  -NoWelcome

$Result=""   
$Results=@()  
$Print=0
$ShowAllSubscription=$False
$PrintedOutput=0

#Output file declaration 
$Location=Get-Location
$ExportCSV="$Location\LicenseExpiryReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" 

#Check for filters
if((!($Trial.IsPresent)) -and (!($Free.IsPresent)) -and (!($Purchased.IsPresent)) -and (!($Expired.IsPresent)) -and (!($Active.IsPresent)))
{
 $ShowAllSubscription=$true
}

#FriendlyName list for license plan 
$FriendlyNameHash=@()
$FriendlyNameHash=Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction Stop | ConvertFrom-StringData 


#Get next lifecycle date
$ExpiryDateHash=@{}
$LifeCycleDateInfo=(Invoke-MgGraphRequest -Uri https://graph.microsoft.com/V1.0/directory/subscriptions -Method Get).Value
foreach($Date in $LifeCycleDate)
{
 $ExpiryDateHash.Add($Date.skuId,$Date.nextLifeCycleDateTime)
}
$Count=0
#Get available subscriptions in the tenant
$Subscriptions= Get-MgBetaSubscribedSku -All | foreach{
$Count++
Write-Progress -Activity "Processed Subscription count: $Count Currently processing user: $($_.SKUPartNumber)"
 $SubscriptionName=$_.SKUPartNumber
 $SkuId=$_.SkuId
 $ConsumedUnits=$_.ConsumedUnits
 $MoreSkuDetails=$LifeCycleDateInfo | Where {$_.skuId -eq $SkuId}
 $SubscribedOn=$MoreSkuDetails.createdDateTime
 $Status=$MoreSkuDetails.status
 $TotalLicenses=$MoreSkuDetails.totalLicenses
 $ExpiryDate=$MoreSkuDetails.nextLifeCycleDateTime
 $RemainingUnits=$TotalLicenses - $ConsumedUnits
 $Print=0

 #Convert Skuid to friendly name  
 $EasyName=$FriendlyNameHash[$SubscriptionName] 
 $EasyName
 if(!($EasyName)) 
 {
  $NamePrint=$SubscriptionName
 } 
 else 
 {
  $NamePrint=$EasyName
 } 
 
 #Convert Subscribed date to friendly subscribed date
 $SubscribedDate=(New-TimeSpan -Start $SubscribedOn -End (Get-Date)).Days
 if($SubscribedDate -eq 0)
 {
  $SubscribedDate="Today"
 }
 else
 {
  $SubscribedDate="$SubscribedDate days ago"
 }
 $SubscribedDate="(" + $SubscribedDate + ")"
 $SubscribedDate="$SubscribedOn $SubscribedDate"

 #Determine subscription type
  if(($SubscriptionName -like "*Free*") -and ($ExpiryDate -eq $null))
  {
   $SubscriptionType="Free"
  }
  elseif($ExpiryDate -eq $null)
  {
   $SubscriptionType="Trial"
  }
 else
 {
  $SubscriptionType="Purchased"
 }
 
 #Friendly Expiry Date
 if($ExpiryDate -ne $null)
 {
  $FriendlyExpiryDate=(New-TimeSpan -Start (Get-Date) -End $ExpiryDate).Days
  if($Status -eq "Enabled")
  {
   $FriendlyExpiryDate="Will expire in $FriendlyExpiryDate days"
  }
  elseif($Status -eq "Warning")
  {
   $FriendlyExpiryDate="Expired.Will suspend in $FriendlyExpiryDate days"
  }
  elseif($Status -eq "Suspended")
  {
   $FriendlyExpiryDate="Expired.Will delete in $FriendlyExpiryDate days"
  }
  elseif($Status -eq "LockedOut")
  {
   $FriendlyExpiryDate="Subscription is locked.Please contact Microsoft"
  }
 }
 else
 {
  $ExpiryDate="-"
  $FriendlyExpiryDate="Never Expires"
 }
 
 #Check for filters
 if($ShowAllSubscription -eq $true)
 {
  $Print=1
 }
 else
 {
  if(($Trial.IsPresent) -and ($SubscriptionType -eq "Trial"))
  {
   $Print=1
  }
  if(($Free.IsPresent) -and ($SubscriptionType -eq "Free"))
  {
   $Print=1
  }
  if(($Purchased.IsPresent) -and ($SubscriptionType -eq "Purchased"))
  {
   $Print=1
  }
  if(($Expired.IsPresent) -and ($Status -ne "Enabled"))
  {
   $Print=1
  }
  if(($Active.IsPresent) -and ($Status -eq "Enabled"))
  {
   $Print=1
  }
 }
 


 #Export result to csv
 if($Print -eq 1)
 {
  $PrintedOutput++
  $Result=@{'Subscription Name'=$SubscriptionName;'SKU Id'=$SkuId;'Friendly Subscription Name'=$NamePrint;'Subscribed Date'=$SubscribedDate;'Total Units'=$TotalLicenses;'Consumed Units'=$ConsumedUnits;'Remaining Units'=$RemainingUnits;'License Expiry Date/Next LifeCycle Activity Date'=$ExpiryDate;'Friendly Expiry Date'=$FriendlyExpiryDate;'Subscription Type'=$SubscriptionType;'Status'=$Status}
  $Results= New-Object PSObject -Property $Result  
  $Results | Select-Object 'Subscription Name','Friendly Subscription Name','Subscribed Date','Total Units','Consumed Units','Remaining Units','Subscription Type','License Expiry Date/Next LifeCycle Activity Date','Friendly Expiry Date','Status','SKU Id' | Export-Csv -Path $ExportCSV -Notype -Append 
 }
}

Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed

Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 



