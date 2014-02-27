param (
    [Parameter(Mandatory = $true)] [String] $DCLocation, 
    [Parameter(Mandatory = $true)] [String] $AppDatabaseName, 
    [Parameter(Mandatory = $true)] [String] $ClientIP,
    [Parameter(Mandatory = $true)] [String] $Username,
    [Parameter(Mandatory = $true)] [String] $Password     
)

# Check if Windows Azure Powershell is avaiable 
if ((Get-Module -ListAvailable Azure) -eq $null) { 
    throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools" 
} 

$secPassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential ($Username, $secPassword)

# Create Database Server
Write-Host "create SQL Azure Database Server" 
$dbServer = New-AzureSqlDatabaseServer -AdministratorLogin $Username `
    -AdministratorLoginPassword $Password `
    -Location $DCLocation 
$dbServerName = $dbServer.ServerName
Write-Host "SQL Azure Database Server '"$dbServerName"' created." 
 
# Apply Firewall Rules 
$clientFirewallRuleName = "ClientIPAddress_" + [DateTime]::UtcNow 
Write-Host "create client firewall rule '$clientFirewallRuleName'." 
New-AzureSqlDatabaseServerFirewallRule -ServerName $dbServerName `
-RuleName $clientFirewallRuleName -StartIpAddress $ClientIP -EndIpAddress $ClientIP | Out-Null   

$azureFirewallRuleName = "AzureServices" 
Write-Host "create Azure Services firewall rule '$azureFirewallRuleName'." 
New-AzureSqlDatabaseServerFirewallRule -ServerName $dbServerName `
-RuleName $azureFirewallRuleName -StartIpAddress "0.0.0.0" -EndIpAddress "0.0.0.0" | Out-Null 
 
# Create Database 
$context = New-AzureSqlDatabaseServerContext -ServerName $dbServerName -Credential $credential 
Write-Host "create database '$AppDatabaseName' on database server $dbServerName" 
$database = New-AzureSqlDatabase -DatabaseName $AppDatabaseName -Context $context 

return [string]"$dbServerName"
