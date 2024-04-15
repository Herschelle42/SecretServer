Function Get-SSToken {
<#
.SYNOPSIS
  Get Secret Server access token for use with REST API calls

.NOTES
  Author: Clint Fritz

  TODO: add test that username may require domain\user

.EXAMPLE
    PS> $computerName = "secretserver.corp.local"
    PS> $Credential = Get-Credential
    PS> $authtoken = Get-SSToken -ComputerName $computerName -Credential $Credential
    PS> $authtoken.access_token

    AgIfYQQam5uHRE_AkJOISpLIubAxFXTiiVYFxxb-qAtf4Be5BFXxiz3CD4f3W5u-E9eBsz2ODefoRjR8YpWol3gG7oy7aTrci6_WGRh
    bb4VCrigJK42stv66MZLpfQPi9LGlkkH_9WSDPhFFcmppAH4vvIunefXyZwNGkIFh37b4WkpJYYBbbzJGp9J21vkL8JHWuUIkveo6v-
    JU0Ebeg1vYGJwhGYJZQaKmvkBwY60F1wSuljou4kt0DDlUlKDmMVa-hpMoirt4J_K8vPbLP_2PBvmNTH3KbjGvwUqB_zLVlhlDyz_q0


#>
[CmdletBinding(DefaultParameterSetName="ByCredential")]
Param(
    #Protocol. https is the default.
    [Parameter(Mandatory=$false)]
    [ValidateSet("https","http")]
    [string]$Protocol="https",

    #Computer name
    [Parameter(Mandatory)]
    [Alias("Server","IPAddress","FQDN")]
    [string]$ComputerName,

    #Port
    [Parameter(Mandatory=$false)]
    [ValidatePattern("^[1-9][0-9]{0,4}$")]
    [int]$Port,

    #Credential
    [Parameter(Mandatory,ParameterSetName="ByCredential")]
    [ValidateNotNullOrEmpty()]
    [Management.Automation.PSCredential]$Credential,
        
    #Username
    [Parameter(Mandatory,ParameterSetName="ByUsername")]
    [string]$Username,

    #Password
    [Parameter(Mandatory,ParameterSetName="ByUsername")]
    [SecureString]$Password,

    #Is 2FA required? Default is false
    [Switch] $UseTwoFactor = $false,

    #Choose the output as a REST header. Default is false.
    [Switch] $AsHeader=$false
)

Begin {
    switch ($PSCmdlet.ParameterSetName) {
        "ByCredential" {
            Write-Verbose "[INFO] Using Credential: $($Credential.UserName)"
            $creds = @{
                username = $Credential.UserName
                password = $Credential.GetNetworkCredential().Password
                grant_type = "password"
            }
        }
        "ByUsername" {
            Write-Verbose "[INFO] Using username and password: $($Username)"
             $creds = @{
                username = "$($username)"
                password = $password
                grant_type = "password"
            }
        }
        "__AllParameterSets" {}
    }
}

Process {
    If ($UseTwoFactor) {
        $headers = @{
            "OTP" = (Read-Host -Prompt "Enter your OTP for 2FA: ")
        }
    } else { 
        $headers = $null
    }

    Write-Verbose "[INFO] Build server uri"
    $serverUri = $null
    if($Port) {
        $serverUri = "$($protocol)://$($ComputerName):$($Port)"
    } else {
        $serverUri = "$($protocol)://$($ComputerName)"
    }
    Write-Verbose "[INFO] Server uri: $($serverUri)"

    try
    {
        $response = Invoke-WebRequest -Uri "$serverUri/SecretServer/oauth2/token" -Method Post -Body $creds -Headers $headers | Select -ExpandProperty Content | ConvertFrom-Json
    }
    catch
    {
        $result = $_.Exception.Response.GetResponseStream();
        $reader = New-Object System.IO.StreamReader($result);
        $reader.BaseStream.Position = 0;
        $reader.DiscardBufferedData();
        $responseBody = $reader.ReadToEnd() | ConvertFrom-Json
        Write-Error "$($responseBody.error)"
        return;
    }

    if ($AsHeader) {
        Write-Verbose "[INFO] Creating headers output"


        return $headers

    } else {

        Write-Verbose "[INFO] Calculate and add the expiry time"
        $response | Add-Member -Name expires -MemberType NoteProperty -Value $((get-date).AddSeconds($response.expires_in))

        return $response
    }
    Write-Verbose "[INFO] $(Get-Date) End of Process"
}

End {
    Write-Verbose "[INFO] $(Get-Date) End"
}

}
