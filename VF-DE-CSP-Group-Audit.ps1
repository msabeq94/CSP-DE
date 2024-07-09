Get-MgUser -UserId "6d60d267-b4ca-4d71-a9fe-ad19e11b66ac" # Get the user
$user = Get-MgUser -UserId "6d60d267-b4ca-4d71-a9fe-ad19e11b66ac"

# Get the user type
$userType = $user.UserType

# Output the user type
Write-Host "User type: $userType"# Get the user
$user = Get-MgUser -UserId "6d60d267-b4ca-4d71-a9fe-ad19e11b66ac" -Select "Id, UserType"

# Get the user type
$userType = $user.UserType

# Output the user type
Write-Host "User type: $userType"




