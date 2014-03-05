param (
	[Parameter(Mandatory = $true)] [String] $AzureSubscription,
    [Parameter(Mandatory = $true)] [String] $DCLocation,
    [Parameter(Mandatory = $true)] [String] $FrontendReleaseName,
    [Parameter(Mandatory = $true)] [String] $BackendReleaseName,
    [Parameter(Mandatory = $true)] [Boolean] $DeleteExistingWebSites,
    [Parameter(Mandatory = $true)] [Boolean] $CreateNewDatabase
)

$config = @{
	frontendName = "MsgSolCB-Frontend-$FrontendReleaseName";
	backendName = "MsgSolCB-Backend-$BackendReleaseName"
}

if ((Test-Path "azure.err") -eq $True) {
	Write-Host "azure.err will be deleted"
	del azure.err
}

# Check if Windows Azure Powershell is avaiable
if ((Get-Module -ListAvailable Azure) -eq $null) {
    throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
}

Function Test-AzureWebSiteNameAvailable {
	param (
    	[Parameter(Mandatory = $true)] [String] $WebSiteName
	)
	if ((Get-AzureWebsite | Where-Object {$_.Name -eq $WebSiteName }) -ne $null) {
		Write-Host "Web Site $WebSiteName already exists as part of subscription $AzureSubscription"
		Write-Output $True
	}
	else {
		try {
			[net.dns]::GetHostEntry("$WebSiteName.azurewebsites.net")
			Write-Host - "Web Site name $WebSiteName is already used by another subscription"
			Write-Output $False
		}
		catch {
			Write-Host "Web Site $WebSiteName is available" 
			Write-Output $True
		}
	}
}

Write-Host "create and configure messaging solution in $AzureSubscription"
try{
	Write-Host "set subscription for PowerShell"
	Select-AzureSubscription $AzureSubscription

	Write-Host "set subscription for CLI"
	azure account set $AzureSubscription

	if ((Test-AzureWebSiteNameAvailable $config.backendName) -eq $False) {
		break
	}

	if ((Test-AzureWebSiteNameAvailable $config.frontendName) -eq $False) {
		break
	}

	Write-Host "create and configure backend "$config.backendName
	$backendURLs = .\Create-MessagingBackend $DCLocation $config.backendName $DeleteExistingWebSites $CreateNewDatabase
	Write-Host "create and configure frontend "$config.frontendName
	.\Create-MessagingFrontend $DCLocation $config.frontendName $backendURLs.Url $backendURLs.StagingUrl $DeleteExistingWebSites

	if ((Test-Path "azure.err") -eq $True) {
		Write-Host "`n`nCLI ERRORS - check azure.err for details on errors`n"
	}
	else {
		Write-Host "`n`nCLI & POWERSHELL SUCCESS - no error logged through CLI or PowerShell commands`n"	
	}
}
catch {
	Write-Host "`n`n POWERSHELL ERROR - Azure PowerShell command terminated with the following error:"
	Write-Host $_
}



