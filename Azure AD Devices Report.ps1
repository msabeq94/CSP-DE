Connect-MgGraph -Scopes "Directory.Read.All,BitLockerKey.Read.All"  -ErrorAction SilentlyContinue -Errorvariable ConnectionError |Out-Null

Write-Host "Microsoft Graph Beta Powershell module is connected successfully" -ForegroundColor Green


$ExportCSV =".\AzureDeviceReport_$((Get-Date -format MMM-dd` hh-mm-ss` tt).ToString()).csv" 
$Report=""
$FilterCondition = @()
$DeviceInfo = Get-MgBetaDevice -All
if($DeviceInfo -eq $null)
{
    Write-Host "You have no devices enrolled in your Azure AD" -ForegroundColor Red
    CloseConnection
}
# if($EnabledDevice.IsPresent)
# {
#     $DeviceInfo = $DeviceInfo | Where-Object {$_.AccountEnabled -eq $True}
# }
# elseif($DisabledDevice.IsPresent)
# {
#     $DeviceInfo = $DeviceInfo | Where-Object {$_.AccountEnabled -eq $False}
# }
# if($ManagedDevice.IsPresent)
# {
#     $DeviceInfo = $DeviceInfo | Where-Object {$_.IsManaged -eq $True}
# }
$TimeZone = (Get-TimeZone).Id
Foreach($Device in $DeviceInfo){
    Write-Progress -Activity "Fetching devices: $($Device.DisplayName)"
    $LastSigninActivity = "-"
    if(($Device.ApproximateLastSignInDateTime -ne $null))
    {
        $LastSigninActivity = (New-TimeSpan -Start $Device.ApproximateLastSignInDateTime).Days
    }
    if($Certificate -eq $null)
    {
        $BitLockerKeyIsPresent = "No"
        try {
            $BitLockerKeys = Get-MgBetaInformationProtectionBitlockerRecoveryKey -Filter "DeviceId eq '$($Device.DeviceId)'" -ErrorAction SilentlyContinue -ErrorVariable Err
            if($Err -ne $null)
            {
                Write-Host $Err -ForegroundColor Red
                CloseConnection
            }
        }
        catch
        {
            Write-Host $_.Exception.Message -ForegroundColor Red
            CloseConnection
        }
        if($BitLockerKeys -ne $null)
        {
            $BitLockerKeyIsPresent = "Yes"
        }
        if($DevicesWithBitLockerKey.IsPresent)
        {
            if($BitLockerKeyIsPresent -eq "No")
            {
                Continue
            }
        }
    }
    if($InactiveDays -ne "")
    {
        if(($Device.ApproximateLastSignInDateTime -eq $null))
        {
            Continue
        }
        if($LastSigninActivity -le $InactiveDays) 
        {
            continue
        }
    }
    $DeviceOwners = Get-MgBetaDeviceRegisteredOwner -DeviceId $Device.Id -All |Select-Object -ExpandProperty AdditionalProperties
    $DeviceUsers = Get-MgBetaDeviceRegisteredUser -DeviceId $Device.Id -All |Select-Object -ExpandProperty AdditionalProperties
    $DeviceMemberOf = Get-MgBetaDeviceMemberOf -DeviceId $Device.Id -All |Select-Object -ExpandProperty AdditionalProperties
    $Groups = $DeviceMemberOf|Where-Object {$_.'@odata.type' -eq '#microsoft.graph.group'}
    $AdministrativeUnits = $DeviceMemberOf|Where-Object{$_.'@odata.type' -eq '#microsoft.graph.administrativeUnit'}
    if($Device.TrustType -eq "Workplace")
    {
        $JoinType = "Azure AD registered"
    }
    elseif($Device.TrustType -eq "AzureAd")
    {
        $JoinType = "Azure AD joined"
    }
    elseif($Device.TrustType -eq "ServerAd")
    {
        $JoinType = "Hybrid Azure AD joined"
    }
    
    if($Device.ApproximateLastSignInDateTime -ne $null)
    {
        $LastSigninDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($Device.ApproximateLastSignInDateTime,$TimeZone) 
        $RegistrationDateTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($Device.RegistrationDateTime,$TimeZone)
    }
    else
    {
        $LastSigninDateTime = "-"
        $RegistrationDateTime = "-"
    }
    $ExtensionAttributes = $Device.ExtensionAttributes
    $AttributeArray = @()
    $Attributes = $ExtensionAttributes.psobject.properties |Where-Object {$_.Value -ne $null -and $_.Name -ne "AdditionalProperties"}| select Name,Value
    Foreach($Attribute in $Attributes)
    {
        $AttributeArray+=$Attribute.Name+":"+$Attribute.Value
    }
    $ExportResult = @{'Name'                 =$Device.DisplayName
                    'Enabled'                ="$($Device.AccountEnabled)"
                    'Operating System'       =$Device.OperatingSystem
                    'OS Version'             =$Device.OperatingSystemVersion
                    'Join Type'              =$JoinType
                    'Owners'                 =(@($DeviceOwners.userPrincipalName) -join ',')
                    'Users'                  =(@($DeviceUsers.userPrincipalName)-join ',')
                    'Is Managed'             ="$($Device.IsManaged)"
                    'Management Type'        =$Device.ManagementType
                    'Is Compliant'           ="$($Device.IsCompliant)"
                    'Registration Date Time' =$RegistrationDateTime
                    'Last SignIn Date Time'  =$LastSigninDateTime
                    'InActive Days'           =$LastSigninActivity
                    'Groups'                 =(@($Groups.displayName) -join ',')
                    'Administrative Units'   =(@($AdministrativeUnits.displayName) -join ',')
                    'Device Id'              =$Device.DeviceId
                    'Object Id'              =$Device.Id
                    'BitLocker Encrypted'    =$BitLockerKeyIsPresent
                    'Extension Attributes'   =(@($AttributeArray)| Out-String).Trim()
                    }
    $Results = $ExportResult.GetEnumerator() | Where-Object {$_.Value -eq $null -or $_.Value -eq ""} 
    Foreach($Result in $Results){
        $ExportResult[$Result.Name] = "-"
    }
    $Report = [PSCustomObject]$ExportResult
    if($Certificate -eq $null)
    {
        $Report|Select 'Name','Enabled','Operating System','OS Version','Join Type','Owners','Users','Is Managed','Management Type','Is Compliant','Registration Date Time','Last SignIn Date Time','InActive Days','Groups','Administrative Units','Device Id','Object Id','BitLocker Encrypted','Extension Attributes' | Export-csv -path $ExportCSV -NoType -Append  
    }
    else
    {
        $Report|Select 'Name','Enabled','Operating System','OS Version','Join Type','Owners','Users','Is Managed','Management Type','Is Compliant','Registration Date Time','Last SignIn Date Time','InActive Days','Groups','Administrative Units','Device Id','Object Id','Extension Attributes' | Export-csv -path $ExportCSV -NoType -Append          
    }
   

}
Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed

Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 
    


