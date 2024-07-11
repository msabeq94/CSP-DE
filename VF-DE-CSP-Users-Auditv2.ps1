# Connect to Microsoft Graph API
Connect-MgGraph -Scopes "AuditLog.Read.All", "User.Read.All", "Directory.Read.All", "UserAuthenticationMethod.Read.All", "UserAuthenticationMethod.ReadWrite.All", "User.ReadWrite","Organization.Read.All"
# Get all users
$users = Get-MgUser -All -Select "Id, UserType, DisplayName, UserPrincipalName, Mail, AccountEnabled"
# Get all MFA registration details
$mfaRegistrationDetails = Get-MgReportAuthenticationMethodUserRegistrationDetail -All

# Initialize an array to hold the user data
$userData = @()

# Loop through each user
foreach ($user in $users) {

    $userId = $user.Id
    $userName = $user.DisplayName
    $userPrincipalName = $user.UserPrincipalName
    $userType = $user.UserType
    $userstatus = $user.AccountEnabled

    # Get the sign-in logs for the user
# Get the sign-in activities
$signInActivities = Get-MgBetaAuditLogSignIn -Filter "UserId eq '$userId'" -All | Sort-Object CreatedDateTime -Descending

if ($signInActivities  -ne $null) {
    # Get the last interactive sign-in
    $lastInteractiveSignIn = $signInActivities | Where-Object { $_.IsInteractive -eq $true } | Select-Object -First 1

    # Get the last non-interactive sign-in
    $lastNonInteractiveSignIn = $signInActivities | Where-Object { $_.IsInteractive -eq $false } | Select-Object -First 1

    if ($lastInteractiveSignIn) {
        # Convert the CreatedDateTime to local timezone
        $lastInteractiveSignInDate = [DateTime]::SpecifyKind($lastInteractiveSignIn.CreatedDateTime, 'Local')
        
        $daysSinceLastInteractiveSignIn = ((Get-Date) - $lastInteractiveSignInDate).Days
       
        if ($daysSinceLastInteractiveSignIn -eq 0) {
            Write-Host "The last interactive sign-in was today."
            $DDSinceLastInteractiveSignIn = "Today"
            $InteractiveSignInDate = $lastInteractiveSignInDate.ToString("yyyy/MM/dd")
        } else {
            Write-Host "The last interactive sign-in was $daysSinceLastInteractiveSignIn days ago."
            $InteractiveSignInDate = $lastInteractiveSignInDate.ToString("yyyy/MM/dd")
            $DDSinceLastInteractiveSignIn = $daysSinceLastInteractiveSignIn
        }
    } else {
        Write-Host "No interactive sign-in found."
      $InteractiveSignInDate = 'NA'
     $DDSinceLastInteractiveSignIn = 'NA'

    }

    if ($lastNonInteractiveSignIn) {
        # Convert the CreatedDateTime to local timezone
        $lastNonInteractiveSignInDate = [DateTime]::SpecifyKind($lastNonInteractiveSignIn.CreatedDateTime, 'Local')
       
        $daysSinceLastNonInteractiveSignIn = ((Get-Date) - $lastNonInteractiveSignInDate).Days
        if ($daysSinceLastNonInteractiveSignIn -eq 0) {
            Write-Host "The last non-interactive sign-in was today."
            $DDaysSinceLastNonInteractiveSignIn = 'Today'
            $NonInteractiveSignInDate =  $lastNonInteractiveSignInDate.ToString("yyyy/MM/dd")
        } else {
            Write-Host "The last non-interactive sign-in was $daysSinceLastNonInteractiveSignIn days ago."
            $NonInteractiveSignInDate =  $lastNonInteractiveSignInDate.ToString("yyyy/MM/dd")
            $DDaysSinceLastNonInteractiveSignIn = $daysSinceLastNonInteractiveSignIn
        }
    } else {
        Write-Host "No non-interactive sign-in found."
     $NonInteractiveSignInDate = 'NA'
     $DDaysSinceLastNonInteractiveSignIn= 'NA'
                                             
    }
} else {
    Write-Host "No sign-in activities found for the user."
     $NonInteractiveSignInDate = 'NA'
     $DDaysSinceLastNonInteractiveSignIn= 'NA'
     $InteractiveSignInDate = 'NA'
     $DDSinceLastInteractiveSignIn = 'NA'
}

    # Get the MFA status for the user
# Filter the details for the specific user
$userMfaRegistrationDetails = $mfaRegistrationDetails | Where-Object { $_.UserPrincipalName -eq $userPrincipalName }

 $IsMfaCapable = $userMfaRegistrationDetails.IsMfaCapable
 $IsMfaRegistered = $userMfaRegistrationDetails.IsMfaRegistered

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
        FullName = $userName
        UserId = $userId
        UserType = $userType
        Userstatus = $userstatus
        UserPrincipalName = $userPrincipalName
        IsMfaCapable = $IsMfaCapable
        IsMfaRegistered =  $IsMfaRegistered 
        lastInteractiveSignInDate = $InteractiveSignInDate 
        daysSinceLastInteractiveSignIn = $DDSinceLastInteractiveSignIn
        lastNonInteractiveSignInDate = $NonInteractiveSignInDate
        daysSinceLastNonInteractiveSignIn = $DDaysSinceLastNonInteractiveSignIn
        MfaEnabled = $mfaEnabled -join ', '
        Groups = $groups -join ', '
        DirectoryRoles = $directoryRoles -join ', '
        AlternativeEmail = $alternativeEmail
        Licenses = $licenses -join ', '
    }
    
    
}

# Export the user data to a CSV file
$userData | Select-Object FullName, UserId, UserType,Userstatus,UserPrincipalName, IsMfaCapable,IsMfaRegistered,lastInteractiveSignInDate ,daysSinceLastInteractiveSignIn,lastNonInteractiveSignInDate,daysSinceLastNonInteractiveSignIn, Groups, DirectoryRoles, Licenses, AlternativeEmail | Export-Csv -Path 'C:\user_all11.csv' -NoTypeInformation

# Disconnect from Microsoft Graph API
Disconnect-MgGraph


