

Connect-MgGraph -Scopes "User.Read.All","AuditLog.read.All"  -NoWelcome


$ExportCSV = ".\M365GuestUserS_LastLoginTime_Report_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm-ss` tt).ToString()).csv"
$ExportResult=""   
$ExportResults=@()  

#Get friendly name of license plan from external file
$FriendlyNameHash=Get-Content -Raw -Path .\LicenseFriendlyName.txt -ErrorAction Stop | ConvertFrom-StringData

$Count=0
$PrintedUser=0
#retrieve users
$RequiredProperties=@('UserPrincipalName','CreatedDateTime','AccountEnabled','Department','JobTitle','RefreshTokensValidFromDateTime','SigninActivity')
Get-MgBetaUser -Filter "userType eq 'Guest'" -All -Property $RequiredProperties | select $RequiredProperties | ForEach-Object {
 $Count++
 $UPN=$_.UserPrincipalName
 Write-Progress -Activity "`n     Processing user: $Count - $UPN"
 $LastInteractiveSignIn=$_.SignInActivity.LastSignInDateTime
 $LastNon_InteractiveSignIn=$_.SignInActivity.LastNonInteractiveSignInDateTime
 $LastSuccessfulSignInTime=$_.SignInActivity.lastSuccessfulSignInDateTime
 $CreatedDate=$_.CreatedDateTime
 $AccountEnabled=$_.AccountEnabled
 $Department=$_.Department
 $JobTitle=$_.JobTitle
 $RefreshTokenValidFrom=$_.RefreshTokensValidFromDateTime
 #Calculate Inactive days
 if($LastInteractiveSignIn -eq $null)
 {
  $LastInteractiveSignIn = "Never Logged In"
  $InactiveDays_InteractiveSignIn = "-"
 }
 else
 {
  $InactiveDays_InteractiveSignIn = (New-TimeSpan -Start $LastInteractiveSignIn).Days
 }
 if($LastNon_InteractiveSignIn -eq $null)
 {
  $LastNon_InteractiveSignIn = "Never Logged In"
  $InactiveDays_NonInteractiveSignIn = "-"
 }
 else
 {
  $InactiveDays_NonInteractiveSignIn = (New-TimeSpan -Start $LastNon_InteractiveSignIn).Days
 }
 if($AccountEnabled -eq $true)
 {
  $AccountStatus='Enabled'
 }
 else
 {
  $AccountStatus='Disabled'
 }

 #Get licenses assigned to mailboxes
 $Licenses = (Get-MgBetaUserLicenseDetail -UserId $UPN).SkuPartNumber
 $AssignedLicense = @()

 #Convert license plan to friendly name
 if($Licenses.count -eq 0)
 {
  $LicenseDetails = "No License Assigned"
 }
 else
 {
  foreach($License in $Licenses)
  {
   $EasyName = $FriendlyNameHash[$License]
   if(!($EasyName))
   {$NamePrint = $License}
   else
   {$NamePrint = $EasyName}
   $AssignedLicense += $NamePrint
  }
  $LicenseDetails = $AssignedLicense -join ", "
 }
 $Print=1


 #Inactive days based on interactive signins filter
 if($InactiveDays_InteractiveSignIn -ne "-")
 {
  if(($InactiveDays -ne "") -and ($InactiveDays -gt $InactiveDays_InteractiveSignIn))
  {
   $Print=0
  }
 }
    
 #Inactive days based on non-interactive signins filter
 if($InactiveDays_NonInteractiveSignIn -ne "-")
 {
  if(($InactiveDays_NonInteractive -ne "") -and ($InactiveDays_NonInteractive -gt $InactiveDays_NonInteractiveSignIn))
  {
   $Print=0
  }
 }

 #Never Logged In user
 if(($ReturnNeverLoggedInUser.IsPresent) -and ($LastInteractiveSignIn -ne "Never Logged In"))
 {
  $Print=0
 }

 
 #Signin Allowed Users
 if($EnabledUsersOnly.IsPresent -and $AccountStatus -eq 'Disabled')
 {      
  $Print=0
 }

 #Signin disabled users
 if($DisabledUsersOnly.IsPresent -and $AccountStatus -eq 'Enabled')
 {
  $Print=0
 }

 #Licensed Users ony
 if($LicensedUsersOnly -and $Licenses.Count -eq 0)
 {
  $Print=0
 }

 #Export users to output file
 if($Print -eq 1)
 {
  $PrintedUser++
  $ExportResult=[PSCustomObject]@{'UPN'=$UPN;'Creation Date'=$CreatedDate;'Last Interactive SignIn Date'=$LastInteractiveSignIn;'Last Non Interactive SignIn Date'=$LastNon_InteractiveSignIn;'Inactive Days(Interactive SignIn)'=$InactiveDays_InteractiveSignIn;'Inactive Days(Non-Interactive Signin)'=$InactiveDays_NonInteractiveSignin;'Refresh Token Valid From'=$RefreshTokenValidFrom;'Last Successful Sign-in Time'=$LastSuccessfulSignInTime;'License Details'=$LicenseDetails;'Account Status'=$AccountStatus;'Department'=$Department;'Job Title'=$JobTitle}
  $ExportResult | Export-Csv -Path $ExportCSV -Notype -Append
 }
}

#Open output file after execution
Write-Host `nScript executed successfully
Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed

Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 



