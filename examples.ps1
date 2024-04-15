
$SecretServer = "secretserver.corp.local"
$Credential = Get-Credential -Message "Secret Server credentials"
$accountName = "InfraDev"

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

#Get AWS Folder
#& = %26
$uri = "$($ssAPIPath)/folders?filter.searchText=AWS"
#$EscapedURI = [uri]::EscapeUriString($URI)
$ongResponse = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json
#$rootFolderId = $ongResponse.records[0].parentFolderId
$awsFolderId = $ongResponse.records[0].Id

#Get account folder
$uri = "$($ssAPIPath)/folders/lookup?filter.parentFolderId=$($awsFolderId)&filter.searchText=$($accountName)"
$folderResponse = Invoke-WebRequest -Uri $uri -Method GET -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json
$folderName = $folderResponse.records | Select -ExpandProperty value
$folderId = $folderResponse.records | Select -ExpandProperty id

#get vRA key pair
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

$accessKey = $secret.items | ? { $_.fieldName -eq "Access Key" } | Select -ExpandProperty itemValue
$secretKey = $secret.items | ? { $_.fieldName -eq "Secret Key" } | Select -ExpandProperty itemValue

Write-Verbose "[INFO] $(Get-Date) Access Key: $($accessKey)"
