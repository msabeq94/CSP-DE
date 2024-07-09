# Connect to Microsoft Graph
Disconnect-MgGraph
Connect-MgGraph -Scopes "AuditLog.Read.All", "User.Read.All", "Directory.Read.All", "UserAuthenticationMethod.Read.All", "UserAuthenticationMethod.ReadWrite.All", "User.ReadWrite"

# Get all users
$users = Get-MgUser -All -Select "Id, UserType,DisplayName,UserPrincipalName,Mail"


# Initialize an array to hold the user data
$userData = @()

# Loop through each user
foreach ($user in $users) {
    $userId = $user.Id
    $UserName = $user.DisplayName
    $UserPrincipalName = $user.UserPrincipalName
    $UserType = $user.UserType

    $signInLogs = Get-MgAuditLogSignIn -Filter "UserId eq '$userId'" -All:$true | Sort-Object CreatedDateTime -Descending

    if ($signInLogs -and $signInLogs.Count -gt 0) {
        $lastSignIn = $signInLogs[0].CreatedDateTime
        if ($lastSignIn -is [DateTime]) {
            $daysSinceLastSignIn = ((Get-Date) - $lastSignIn).Days
            if ($daysSinceLastSignIn -eq 0) {
                Write-Host "The last sign-in was today."
                $daysSignin ="Today"
                
            } else {
                Write-Host "The last sign-in was $daysSinceLastSignIn days ago."
                $daysSignin = ((Get-Date) - $lastSignIn).days
            }}
        
    } else {
        $daysSinceLastSignIn = 'N/A'
        Write-Host "No sign-in logs found for user with Name: $UserName"
        
    }


    
    $daysSignin = $daysSinceLastSignIn
    # Get the MFA status
    $mfaEnabled = (Get-MgUserAuthenticationMicrosoftAuthenticatorMethod -UserId $userId).DisplayName

    # Get the groups the user is a member of
    $groups = Get-MgUserMemberOfAsGroup -UserId $userId | Select-Object -ExpandProperty DisplayName

    # Get the directory roles the user is a member of
    $directoryRoles = Get-MgUserMemberOfAsDirectoryRole -UserId $userId | Select-Object -ExpandProperty DisplayName

    # Get the alternative email address
    $alternativeEmail = $user.Mail
    
    # Get the licenses the user has
    $licenses = Get-MgUserLicenseDetail -UserId $userId | Select-Object -ExpandProperty SkuPartNumber

    # Add the user data to the array
    $userData += New-Object PSObject -Property @{
        fullName = $UserName
        UserId = $userId
        UserType = $UserType
        UserPrincipalName = $UserPrincipalName
        LastSignInDateTime = $lastSignIn
        DaysSinceLastSignIn = $daysSignin 
        MfaEnabled = $mfaEnabled -join ', '
        Groups = $groups -join ', '
        DirectoryRoles = $directoryRoles -join ', '
        AlternativeEmail = $alternativeEmail
        Licenses = $licenses -join ', '
    }
    
    Write-Host "user $UserName"
}

# Export the user data to a CSV file
$userData | Select-Object fullName, UserId,UserType,UserPrincipalName,LastSignInDateTime, DaysSinceLastSignIn, MfaEnabled, Groups, DirectoryRoles,Licenses , AlternativeEmail | Export-Csv -Path 'C:\user_data8.csv' -NoTypeInformation