# Get the license details: number of licenses used and available
$licenseDetails = Get-MgLicenseDetail -All | Select-Object -Property SkuPartNumber, ConsumedUnits, TotalUnits
$licenseDetails | Export-Csv -Path "C:\LicenseDetails.csv" -NoTypeInformation