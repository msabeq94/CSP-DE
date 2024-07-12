Install-Module -Name PartnerCenter -Force -Scope CurrentUser
 
Import-Module PartnerCenter
 
Connect-PartnerCenter
 
# Retrieve the users
$users = Get-PartnerUser
 
 
# Retrieve all roles
$roles = Get-PartnerRole
 
# Initialize an array to store the roles and their members
$roleMembers = @()
 
# Loop through each role and get its members
foreach ($role in $roles) {
    $members = Get-PartnerRoleMember -RoleId $role.RoleId
    foreach ($member in $members) {
        $roleMembers += [PSCustomObject]@{
            RoleName = $role.Name
            MemberName = $member.UserPrincipalName
            MemberDisplayName = $member.DisplayName
        }
    }
}
 
# Export to CSV
$roleMembers | Export-Csv -Path "C:\PartnerCenterUserRoles.csv" -NoTypeInformation
 
Write-Output "Role members have been exported to PartnerCenterRoleMembers.csv"