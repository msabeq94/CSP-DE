# Connect to Microsoft Graph API
Connect-MgGraph -Scopes "AuditLog.Read.All", "User.Read.All", "Directory.Read.All", "UserAuthenticationMethod.Read.All", "UserAuthenticationMethod.ReadWrite.All", "User.ReadWrite","Organization.Read.All"
Write-Host "Microsoft Graph Beta Powershell module is connected successfully" -ForegroundColor Green


$Location=Get-Location
$ExportCSV="$Location\UserReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
# Get all users
# $users = Get-MgUser  | Convertto-Json
$RequiredProperties=@('DisplayName','UserType','UserPrincipalName','EmployeeId','CreatedDateTime','AccountEnabled','Department','JobTitle','RefreshTokensValidFromDateTime','SigninActivity')
$users = Get-MgUser -All -Property $RequiredProperties  #| Convertto-Json > mos.json
# Initialize an array to hold the user data
$userData = @()
$Count=0
$PrintedUser=0
# Loop through each user
foreach ($user in $users) {
    $Count++
    Write-Progress -Activity "Processed users count: $Count Currently processing user: $($user.DisplayName)"
    $userId = $user.Id
    $userName = $user.DisplayName
    $userPrincipalName = $user.UserPrincipalName
    $userType = $user.UserType
    $userDepartment = $user.Department
    $usejobTitle = $user.JobTitle
    $userCreationDate = $user.CreatedDateTime
    $userAccountAge = (New-TimeSpan -Start $userCreationDate).Days
    if( $user.AccountEnabled -eq $true)
    {
     $SigninStatus="Allowed"
    }
    else
    {
     $SigninStatus="Blocked"
    }
    $LastInteractiveSignIn=$user.SignInActivity.LastSignInDateTime
    $LastNon_InteractiveSignIn=$user.SignInActivity.LastNonInteractiveSignInDateTime

    #Calculate Inactive days
    if($LastInteractiveSignIn -eq $null)
    {
    $LastInteractiveSignIn = "Never Logged In"
    $InactiveDays_InteractiveSignIn = "-"
    }
    else
    {
    $InactiveDays_InteractiveSignIn = (New-TimeSpan -Start  $LastInteractiveSignIn).Days
    }
    if($LastNon_InteractiveSignIn -eq $null)
    {
    $LastNon_InteractiveSignIn = "Never Logged In"
    $InactiveDays_NonInteractiveSignIn = "-"
    }
    else
    {
    $InactiveDays_NonInteractiveSignIn = (New-TimeSpan -Start  $LastNon_InteractiveSignIn).Days
    }
    $Is3rdPartyAuthenticatorUsed="False"
    $MFAPhone="-"
    $MicrosoftAuthenticatorDevice="-"


[array]$MFAData=Get-MgBetaUserAuthenticationMethod -UserId $userId 

$AuthenticationMethod=@()
$AdditionalDetails=@()

 
foreach($MFA in $MFAData)
{ 
  Switch ($MFA.AdditionalProperties["@odata.type"]) 
  { 
   "#microsoft.graph.passwordAuthenticationMethod"
   {
    $AuthMethod     = 'PasswordAuthentication'
    $AuthMethodDetails = $MFA.AdditionalProperties["displayName"] 
   } 
   "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod"  
   { # Microsoft Authenticator App
    $AuthMethod     = 'AuthenticatorApp'
    $AuthMethodDetails = $MFA.AdditionalProperties["displayName"] 
    $MicrosoftAuthenticatorDevice=$MFA.AdditionalProperties["displayName"]
   }
   "#microsoft.graph.phoneAuthenticationMethod"                  
   { # Phone authentication
    $AuthMethod     = 'PhoneAuthentication'
    $AuthMethodDetails = $MFA.AdditionalProperties["phoneType", "phoneNumber"] -join ' ' 
    $MFAPhone=$MFA.AdditionalProperties["phoneNumber"]
   } 
   "#microsoft.graph.fido2AuthenticationMethod"                   
   { # FIDO2 key
    $AuthMethod     = 'Fido2'
    $AuthMethodDetails = $MFA.AdditionalProperties["model"] 
   }  
   "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" 
   { # Windows Hello
    $AuthMethod     = 'WindowsHelloForBusiness'
    $AuthMethodDetails = $MFA.AdditionalProperties["displayName"] 
   }                        
   "#microsoft.graph.emailAuthenticationMethod"        
   { # Email Authentication
    $AuthMethod     = 'EmailAuthentication'
    $AuthMethodDetails = $MFA.AdditionalProperties["emailAddress"] 
   }               
   "microsoft.graph.temporaryAccessPassAuthenticationMethod"   
   { # Temporary Access pass
    $AuthMethod     = 'TemporaryAccessPass'
    $AuthMethodDetails = 'Access pass lifetime (minutes): ' + $MFA.AdditionalProperties["lifetimeInMinutes"] 
   }
   "#microsoft.graph.passwordlessMicrosoftAuthenticatorAuthenticationMethod" 
   { # Passwordless
    $AuthMethod     = 'PasswordlessMSAuthenticator'
    $AuthMethodDetails = $MFA.AdditionalProperties["displayName"] 
   }      
   "#microsoft.graph.softwareOathAuthenticationMethod"
   { 
     $AuthMethod     = 'SoftwareOath'
     $Is3rdPartyAuthenticatorUsed="True"            
   }
   
  }
  $AuthenticationMethod +=$AuthMethod
  if($AuthMethodDetails -ne "")
  {
   $AdditionalDetails +="$AuthMethod : $AuthMethodDetails"
  }
 }
    #To remove duplicate authentication methods
    $AuthenticationMethod =$AuthenticationMethod | Sort-Object | Get-Unique
    $AuthenticationMethods= $AuthenticationMethod  -join ","
    $AdditionalDetail=$AdditionalDetails -join ", "
 
 #Determine MFA status
 [array]$StrongMFAMethods=("Fido2","PhoneAuthentication","PasswordlessMSAuthenticator","AuthenticatorApp","WindowsHelloForBusiness")
 $MFAStatus="Disabled"


 foreach($StrongMFAMethod in $StrongMFAMethods)
 {
  if($AuthenticationMethod -contains $StrongMFAMethod)
  {
   $MFAStatus="Strong"
   break
  }
 }

 if(($MFAStatus -ne "Strong") -and ($AuthenticationMethod -contains "SoftwareOath"))
 {
  $MFAStatus="Weak"
 }
    # Get the groups the user is a member of
    $groups = Get-MgUserMemberOfAsGroup -UserId $userId | Select-Object -ExpandProperty DisplayName

    # Get the directory roles the user is a member of
    $directoryRoles = Get-MgUserMemberOfAsDirectoryRole -UserId $userId | Select-Object -ExpandProperty DisplayName

    # Get the alternative email address
    $alternativeEmail = $user.Mail
    
    # Get the licenses the user has
    $licenses = Get-MgUserLicenseDetail -UserId $userId | Select-Object -ExpandProperty SkuPartNumber

    # Add the user data to the array
    $userData += [PSCustomObject]@{
        'Full Name' = $userName
        UserId = $userId
        'User Type' = $userType
        'User Status' = $SigninStatus
        'User Principal Name' = $userPrincipalName
        'user Department' = $userDepartment
        'user Job Title' = $usejobTitle
        'User Creation Date' = $userCreationDate
        'User Account Age' = $userAccountAge
        'Authentication Methods' =$AuthenticationMethods
        'MFA Status'=$MFAStatus
        'MFA Phone' =$MFAPhone
        'Microsoft Authenticator Configured Device'=$MicrosoftAuthenticatorDevice
        'Is 3rd-Party Authenticator Used'=$Is3rdPartyAuthenticatorUsed
        'MFA Additional Details'=$AdditionalDetail
        'last Interactive SignIn Date' = $LastInteractiveSignIn
        'Days Since Last Interactive SignIn' = $InactiveDays_InteractiveSignIn
        'last NonInteractive SignIn Date' = $LastNon_InteractiveSignIn
        'Days Since Last NonInteractive SignIn' = $InactiveDays_NonInteractiveSignIn
        Groups = $groups -join ', '
        'Directory Roles'= $directoryRoles -join ', '
        'Alternative Email' = $alternativeEmail
        Licenses = $licenses -join ', '
    }
    
    
}

# Export the user data to a CSV file
$userData | Select-Object 'Full Name','UserId','User Type','User Status','User Principal Name','user Department','user Job Title','User Creation Date','User Account Age','Authentication Methods','MFA Status','MFA Phone','Microsoft Authenticator Configured Device','Is 3rd-Party Authenticator Used','MFA Additional Details','last Interactive SignIn Date','Days Since Last Interactive SignIn','last NonInteractive SignIn Date','Days Since Last NonInteractive SignIn', Groups, 'Directory Roles', Licenses, 'Alternative Email' | Export-Csv -Path $ExportCSV  -NoTypeInformation
Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed

Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 



