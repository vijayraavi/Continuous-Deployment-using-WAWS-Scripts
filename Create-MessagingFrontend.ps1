param (
    [Parameter(Mandatory = $true)] [String] $DCLocation,
    [Parameter(Mandatory = $true)] [String] $WebSiteName,
    [Parameter(Mandatory = $true)] [String] $BackendURL,
    [Parameter(Mandatory = $true)] [String] $BackendStagingURL,
    [Parameter(Mandatory = $true)] [Boolean] $DeleteExistingWebSite
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

    $appSettings = @{
        "MessagesBackendURL" = "$BackendServiceURL"
    }
    
    if ($IsStaging -eq $true) {
        Set-AzureWebsite -Name $WebSiteName -slot staging -AppSettings $appSettings 
        Write-Host "configuring staging slot for $WebSiteName"
        azure site scale instances --instances 1 --size small --slot staging $WebSiteName
    }
    else {
        Set-AzureWebsite -Name $WebSiteName -AppSettings $appSettings
        Write-Host "configuring production slot for $WebSiteName"
        azure site scale instances --instances 1 --size small $WebSiteName
    }
}

if ((Get-AzureWebsite | Where-Object {$_.Name -eq $WebSiteName }) -ne $null) {
    if ($DeleteExistingWebSite -eq $true) {
        Write-Host "Web Site $WebSiteName already exists and will be deleted"
        Remove-AzureWebsite -Name $WebSiteName -Force
    }
    else {
        Write-Host "Web Site $WebSiteName already exists and will be re-configured"
    }
}

# we create the staging site before configure the site 
# this avoids that the prod settings are copied to the staging site
Write-Host "create website $WebSiteName"
New-AzureWebSite -Name $WebSiteName -git -Location $DCLocation
Write-Host "set scale mode to standard for $WebSiteName"
azure site scale mode --mode standard $WebSiteName
Write-Host "create staging slot for website $WebSiteName"
New-AzureWebSite -Name $WebSiteName -git -Location $DCLocation -slot staging 

Configure-MessagingFrontend $false $BackendURL
Configure-MessagingFrontend $true $BackendStagingURL

Write-Host "URL: http://$WebSiteName.azurewebsites.net"
Write-Host "Staging URL: http://$WebSiteStagingName.azurewebsites.net"
Write-Host "creation and configuration is done"
return @{Url="http://$WebSiteName.azurewebsites.net"; StagingUrl="http://$WebSiteName-staging.azurewebsites.net"}

