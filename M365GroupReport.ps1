
Function Get_members
{
    $DisplayName=$_.DisplayName
    Write-Progress -Activity "`n     Processed Group count: $Count "`n"  Getting members of: $DisplayName"
    $EmailAddress=$_.Mail
    if($_.GroupTypes -eq "Unified")
    {
        $GroupType="Microsoft 365"
    }
    elseif($_.Mail -ne $null)
    {
        if($_.SecurityEnabled -eq $false)
        {
            $GroupType="DistributionList"
        }
        else
        {
            $GroupType="MailEnabledSecurity"
        }
    }
    else
    {
        $GroupType="Security"
    }
    $GroupId=$_.Id
    $Recipient=""
    $RecipientHash=@{}
    for($KeyIndex = 0; $KeyIndex -lt $RecipientTypeArray.Length; $KeyIndex += 2)
    {
        $key=$RecipientTypeArray[$KeyIndex]
        $Value=$RecipientTypeArray[$KeyIndex+1]
        $RecipientHash.Add($key,$Value)
    }
    $Members=Get-MgGroupMember -All -GroupId $GroupId
    $MembersCount=$Members.Count
    $Members=$Members.AdditionalProperties
    #Filter for security group
    if(($Security.IsPresent) -and ($GroupType -ne "Security"))
    {
        Return
    }

    #Filter for Distribution list
    if(($DistributionList.IsPresent) -and ($GroupType -ne "DistributionList"))
    {
        Return
    }

    #Filter for mail enabled security group
    if(($MailEnabledSecurity.IsPresent) -and ($GroupType -ne "MailEnabledSecurity"))
    {
        Return
    }

    #GroupSize Filter
    if(([int]$MinGroupMembersCount -ne "") -and ($MembersCount -lt [int]$MinGroupMembersCount))
    {
        Return
    }
    #Check for Empty Group
    elseif($MembersCount -eq 0)
    {
        $MemberName="No Members"
        $MemberEmail="-"
        $RecipientTypeDetail="-"
        Print_Output
    }
    #Loop through each member in a group
    else
    {
        foreach($Member in $Members){
            if($IsEmpty.IsPresent)
            {
                return
            }
            $MemberName=$Member.displayName
            if($Member.'@odata.type' -eq '#microsoft.graph.user')
            {
                $MemberType="User"
            }
            elseif($Member.'@odata.type' -eq '#microsoft.graph.group')
            {
                $MemberType="Group"
            }
            elseif($Member.'@odata.type' -eq '#microsoft.graph.orgContact')
            {
                $MemberType="Contact"
            }
            $MemberEmail=$Member.mail
            if($MemberEmail -eq "")
            {
                $MemberEmail="-"
            }
            #Get Counts by RecipientTypeDetail
            foreach($key in [object[]]$Recipienthash.Keys){
                if(($MemberType -eq $key) -eq "true")
                {
                    [int]$RecipientHash[$key]+=1
                }
            }
            Print_Output
        }
    }
 
    #Order RecipientTypeDetail based on count
    $Hash=@{}
    $Hash=$RecipientHash.GetEnumerator() | Sort-Object -Property value -Descending |foreach{
        if([int]$($_.Value) -gt 0 )
        {
            if($Recipient -ne "")
            {
                $Recipient+=";"
            } 
            $Recipient+=@("$($_.Key) - $($_.Value)")    
        }
        if($Recipient -eq "")
        {
            $Recipient="-"
        }
    }
    #Print Summary report
    $Result=@{'DisplayName'=$DisplayName;'EmailAddress'=$EmailAddress;'GroupType'=$GroupType;'GroupMembersCount'=$MembersCount;'MembersCountByType'=$Recipient}
    $Results= New-Object PSObject -Property $Result 
    $Results | Select-Object DisplayName,EmailAddress,GroupType,GroupMembersCount,MembersCountByType | Export-Csv -Path $ExportSummaryCSV -Notype -Append
}

#Print Detailed Output
Function Print_Output
{
    $Result=@{'GroupName'=$DisplayName;'GroupEmailAddress'=$EmailAddress;'Member'=$MemberName;'MemberEmail'=$MemberEmail;'MemberType'=$MemberType} 
    $Results= New-Object PSObject -Property $Result 
    $Results | Select-Object GroupName,GroupEmailAddress,Member,MemberEmail,MemberType | Export-Csv -Path $ExportCSV -Notype -Append
}


    Connect-MgGraph -Scopes $Scopes

    Write-Host `n"Microsoft Graph connected" -ForegroundColor Green
    #Set output file 
    $ExportCSV=".\M365Group-DetailedMembersReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" #Detailed report
    $ExportSummaryCSV=".\M365Group-SummaryReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv" #Summary report

    #Get a list of RecipientTypeDetail
    $RecipientTypeArray=Get-Content -Path .\RecipientTypeDetails.txt -ErrorAction Stop
    $Result=""  
    $Results=@()
    $Count=0
    Write-Progress -Activity "Collecting group info"
    #Check for input file
    if([string]$GroupIDsFile -ne "") 
    { 
        #We have an input file, read it into memory 
        $DG=@()
        $DG=Import-Csv -Header "DisplayName" $GroupIDsFile
        foreach($item in $DG){
            Get-MgGroup -GroupId $item.displayname | Foreach{
                $Count++
                Get_Members
            }
        }
    }
    else
    {
        #Get all Office 365 group
        Get-MgGroup -All -ErrorAction SilentlyContinue -ErrorVariable PermissionError| Foreach{
            $Count++
            Get_Members
        }
        if($PermissionError)
        {
            Write-Host "Please Add permissions!" -ForegroundColor Red
            CloseConnection
        }
    }

 
    Write-Host `n"Script executed successfully"
    
    Write-Progress -Activity "Exporting data to CSV" -Status "Completed"  -Completed

    Write-Host `n "The Output file availble in:" -NoNewline -ForegroundColor Yellow; Write-Host "$ExportCSV" `n 
