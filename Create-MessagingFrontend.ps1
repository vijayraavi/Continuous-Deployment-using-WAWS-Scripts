param (
    [Parameter(Mandatory = $true)] [String] $DCLocation,
    [Parameter(Mandatory = $true)] [String] $WebSiteName,
    [Parameter(Mandatory = $true)] [String] $BackendURL,
    [Parameter(Mandatory = $true)] [String] $BackendStagingURL
)

# Check if Windows Azure Powershell is avaiable
if ((Get-Module -ListAvailable Azure) -eq $null) {
    throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
}

function Configure-MessagingFrontend {
    [CmdletBinding()]
    param (
    [Parameter(Mandatory = $true)] [Boolean] $IsStaging, 
    [Parameter(Mandatory = $true)] [String] $BackendServiceURL
    )
    $cliSlotOption =$null
    $slotName =$null
    if ($IsStaging -eq $true) {
        $cliSlotOption = "--slot"
        $slotName = "staging"
    }

    Write-Host "configuring application settings $WebSiteName $Slot"
    $appSettings = @{
        "MessagesBackendURL" = "$BackendServiceURL"
    }
    
    if ($IsStaging -eq $true) {
        Set-AzureWebsite -Name $WebSiteName -slot $slotName -AppSettings $appSettings
    }
    else {
        Set-AzureWebsite -Name $WebSiteName -AppSettings $appSettings
    }
}

if ((Get-AzureWebsite | Where-Object {$_.Name -eq $WebSiteName }) -ne $null) {
    Write-Host "Web Site $WebSiteName already exists and will be deleted"
    azure site delete -q $WebSiteName
}

# we create the staging site before configure the site 
# this avoids that the prod settings are copied to the staging site
Write-Host "create website $WebSiteName"
azure site create --location "$DCLocation" --git $WebSiteName
Write-Host "set scale mode to standard for $WebSiteName"
azure site scale mode --mode standard $WebSiteName
azure site create --location "$DCLocation" --git --slot staging $WebSiteName
Configure-MessagingFrontend $false $BackendURL
Configure-MessagingFrontend $true $BackendStagingURL

Write-Host "URL: http://$WebSiteName.azurewebsites.net"
Write-Host "Staging URL: http://$WebSiteStagingName.azurewebsites.net"
Write-Host "creation and configuration is done"
return @{Url="http://$WebSiteName.azurewebsites.net"; StagingUrl="http://$WebSiteName-staging.azurewebsites.net"}

