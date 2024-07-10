
# Get all groups
$groups = Get-MgGroup -All

# Print out the total number of groups in the tenant
Write-Host "Total number of groups in the tenant: $($groups.Count)"

# Initialize an empty array to store all members
$allMembers = @()

# For each group
foreach ($group in $groups) {
    # Output the group ID and display name
    $Group_ID = $group.Id
    $Group_Name = $group.DisplayName
    Write-Host "Group ID: $Group_ID, Display Name: $Group_Name"

    # Get the members of the group
    $members = Get-MgGroupMember -GroupId $group.Id -All | ForEach-Object {
        $user = Get-MgUser -UserId $_.Id
        [PSCustomObject]@{
            Name = $user.DisplayName
            Id = $user.Id
            Group = $Group_Name
        }
    }

    # Add the members to the array
    $allMembers += $members

    # Output the total number of members in the group
    $totalMembers = $members.Count
    Write-Host "Total number of members in the group: $totalMembers"
}

# Export the list of all members with their group to a CSV file
$allMembers | Export-Csv -Path "C:\AllGroupMembers.csv" -NoTypeInformation




