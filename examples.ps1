$SecretServer = "secretserver.corp.local"
$Credential = Get-Credential -Message "Secret Server credentials"
$folder1Name = "InfraDev"
$folder2Name = "AD"
$secretName = "LDAP Account"

#Note: token expires after 2 hours
try
{
    $authToken = Get-SSToken -ComputerName $SecretServer -Credential $Credential
} catch {
    throw
    <#
    ERROR: Get-SSToken : You cannot call a method on a null-valued expression.
    Can indicate that Proxy settings are blocking API access to the server
    #>
}

$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", "Bearer $($authToken.access_token)")
$headers.Add("Content-Type", 'application/json')

$ssAPIPath = "https://$($SecretServer)/SecretServer/api/v1"

#Get version information
$uri = "$($ssAPIPath)/Version"
$versionResponse = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json
Write-Output "[INFO] $(Get-Date) Secret Server Version: $($versionResponse.model.version)"

#Get Folder 1
#& = %26
$uri = "$($ssAPIPath)/folders?filter.searchText=$($folder1Name)"
#$EscapedURI = [uri]::EscapeUriString($URI)
$ongResponse = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json
#$rootFolderId = $ongResponse.records[0].parentFolderId
$folder1Id = $ongResponse.records[0].Id

#Get sub folder
$uri = "$($ssAPIPath)/folders/lookup?filter.parentFolderId=$($folder1Id)&filter.searchText=$($folder2Name)"
$folderResponse = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json
$folderName = $folderResponse.records | Select -ExpandProperty value
$folderId = $folderResponse.records | Select -ExpandProperty id

#get the secret in the folder
Write-Verbose "[INFO] $(Get-Date) Get secret id"
$uri = "$($ssAPIPath)/secrets/lookup?filter.searchText=$($secretName)&filter.folderId=$($folderId)"
$foundSecrets = Invoke-WebRequest -uri $uri -Method GET -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json | Select -ExpandProperty records
if($foundSecrets.count) {
    Write-Warning "Multiple secrets found for: $($secretName) in: $($folderName). - Terminating"
    Return
} elseif ($foundSecrets) {
    $secretId = $foundSecrets.id
} else {
    Write-Warning "No secret found. - Terminating"
    Return
}

$uri = "$($ssAPIPath)/secrets/$($secretId)"
try
{
    $secret = Invoke-WebRequest -uri $uri -Method GET -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json
} catch {
    throw
    Return
}

#display the details of the secret
$secret.items | Select-Object fieldName, itemValue
