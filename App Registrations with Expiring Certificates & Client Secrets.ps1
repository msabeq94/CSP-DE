Connect-MgGraph -Scopes "Application.Read.All"  -NoWelcome
Write-Host "Microsoft Graph Beta Powershell module is connected successfully" -ForegroundColor Green

$Location=Get-Location
$ExportCSV = "$Location\AppRegistration_with_Expiring_CertificatesAndSecrets_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$ExportResult=""   
$AppCount=0
$PrintedCount=0

$RequiredProperties=@('DisplayName','AppId','Id','KeyCredentials','PasswordCredentials','CreatedDateTime','SigninAudience')
Get-MgBetaApplication -All -Property $RequiredProperties | foreach {
 $AppCount++

 $AppName=$_.DisplayName
 $AppId=$_.Id
 Write-Progress -Activity "Processed App registration: $AppCount - $AppName "

 $Secrets=$_.PasswordCredentials
 $Certificates=$_.KeyCredentials

 $AppCreationDate=$_.CreatedDateTime
 $SigninAudience=$_.SignInAudience
 
 $Owners=(Get-MgBetaApplicationOwner -ApplicationId $AppId).AdditionalProperties.userPrincipalName
 $Owners=$Owners -join ","
 if($owners -eq "")
 {
  $Owners="-"
 }

if ($Secrets.Count -eq 0 -and $Certificates.Count -eq 0) {
    $PrintedCount++
    $ExportResult = [PSCustomObject]@{
        'App Name'              = $AppName
        'App Owners'            = $Owners
        'App Id'                = $AppId
        'App Creation Time'     = $AppCreationDate
        'Authentication Type'   = $SigninAudience
        'Credential Type'       = 'None'
        'Credential Name'       = '-'
        'Credential Id'         = '-'
        'Credential Status'     = 'No Credentials'
        'Credential Creation Time' = '-'
        'Credential Expiry Date' = '-'
        'Days to Expiry'        = '-'
        'Friendly Expiry Date'  = 'No Credentials'
    }
    $ExportResult | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
}

if($Secrets.Count -gt 0)
 {
  foreach($Secret in $Secrets )
  {
   $CredentialType="Client Secret"
  
   $DisplayName=$Secret.DisplayName
   $Id=$Secret.KeyId
   $CreatedTime=$Secret.StartDateTime
   $ExpiryDate=$Secret.EndDateTime
   $ExpiryStatusCalculation=(New-TimeSpan -Start (Get-Date).Date -End $ExpiryDate).Days
  
   if($ExpiryStatusCalculation -lt 0)
   {
    $ExpiryStatus="Expired"
    $FriendlyExpiryTime="Expired"
    
   }
   else
   {
    $ExpiryStatus="Active"
    $FriendlyExpiryTime="Expires in $ExpiryStatusCalculation days"
   }
   
   $PrintedCount++
   $ExportResult=[PSCustomObject]@{'App Name'=$AppName;'App Owners'=$Owners;'App Id'=$AppId;'App Creation Time'=$AppCreationDate;'Authentication Type'=$SigninAudience;'Credential Type'=$CredentialType;'Credential Name'=$DisplayName;'Credential Id'=$Id;'Credential Status'=$ExpiryStatus;'Credential Creation Time'=$CreatedTime;'Credential Expiry Date'=$ExpiryDate;'Days to Expiry'=$ExpiryStatusCalculation;'Friendly Expiry Date'=$FriendlyExpiryTime}
   $ExportResult | Export-Csv -Path $ExportCSV -Notype -Append
  
  
 }
 }

 if($Certificates.Count -gt 0)
 {
  foreach ($Certificate in $Certificates)
  {
   $CredentialType="Certificate"
   $DisplayName=$Certificate.DisplayName
   $Id=$Certificate.KeyId
   $CreatedTime=$Certificate.StartDateTime
   $ExpiryDate=$Certificate.EndDateTime
   $ExpiryStatusCalculation=(New-TimeSpan -Start (Get-Date).Date -End $ExpiryDate).Days
   if($ExpiryStatusCalculation -lt 0)
   {
    $ExpiryStatus="Expired"
    $FriendlyExpiryTime="Expired"
   }
   else
   {
    $ExpiryStatus="Active"
    $FriendlyExpiryTime="Expires in $ExpiryStatusCalculation days"
   }
   
  }
  $PrintedCount++
  $ExportResult=[PSCustomObject]@{'App Name'=$AppName;'App Owners'=$Owners;'App Id'=$AppId;'App Creation Time'=$AppCreationDate;'Authentication Type'=$SigninAudience;'Credential Type'=$CredentialType;'Credential Name'=$DisplayName;'Credential Id'=$Id;'Credential Status'=$ExpiryStatus;'Credential Creation Time'=$CreatedTime;'Credential Expiry Date'=$ExpiryDate;'Days to Expiry'=$ExpiryStatusCalculation;'Friendly Expiry Date'=$FriendlyExpiryTime}
  $ExportResult | Export-Csv -Path $ExportCSV -Notype -Append
 }

}

Write-Host `nThe script processed $AppCount app registrations and the output file contains $PrintedCount records.
Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed
Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 
    
