param (
    [Parameter(Mandatory = $true)] [String] $DCLocation,
    [Parameter(Mandatory = $true)] [String] $WebSiteName,
    [Parameter(Mandatory = $true)] [Boolean] $DeleteExistingWebSite,
    [Parameter(Mandatory = $true)] [Boolean] $CreateNewDatabase
)

$config = @{
    storageAccountName = "msgbkdprod";
    stagingStorageAccountName = "msgbkdstaging";
    databaseName = "msgbkddbprod";
    stagingDatabaseName = "msgbkddbstaging";
    dbUsername = "username";
    dbPassword = "pass@w0rd";
}

# Check if Windows Azure Powershell is avaiable
if ((Get-Module -ListAvailable Azure) -eq $null) {
    throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
}

function Create-StorageAccount {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [String] $storageAccountName
    )

    $StorageAccount = Get-AzureStorageAccount | Where-Object {$_.StorageAccountName -eq $storageAccountName } 
    if ($storageAccount -eq $null) {
        Write-Host "create storage account $storageAccountName in $DCLocation"
        New-AzureStorageAccount -StorageAccountName $storageAccountName -Label $storageAccountName -Location $DCLocation
    }
    else {
        Write-Host "storage $storageAccountName already exists"
    }      
}
function Get-BackendDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [String] $AppDatabaseName 
    )    
    $dbServerName = $null
    if ($CreateNewDatabase -eq $true){
        $dbServerName = Create-BackendDatabase $AppDatabaseName
    }
    else {
        Get-AzureSqlDatabaseServer | ForEach-Object {
            $dbServer =$_
            if ($dbServer.Location -eq $DCLocation) {
                if ((Get-AzureSqlDatabase $dbServer.ServerName | Where-Object {$_.Name -eq $AppDatabaseName }) -ne $null) {
                    Write-Host "Using SQLDatabaseServer " $dbServer.ServerName " for database $AppDatabaseName" 
                    $dbServerName = $dbServer.ServerName
                }
            }
        }
        if ($dbServerName -eq $null){
            throw "Couldn't find a SQLDatabaseServer that contains database $AppDatabaseName"
        }
    }
    # Create connection string for database 
    $appDBConnStr  = "Server=tcp:$dbServerName.database.windows.net,1433;Database=$AppDatabaseName;"  
    $appDBConnStr += "User ID=" + $config.dbUsername + "@$dbServerName;Password=" + $config.dbPassword + ";Trusted_Connection=False;Encrypt=True;Connection Timeout=30;" 
    
    return $appDBConnStr
}

function Create-BackendDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [String] $AppDatabaseName 
    )

    $DbServerName = .\Create-SQLDatabase $DCLocation $AppDatabaseName $config.dbUsername $config.dbPassword
    Write-Host "Database $AppDatabaseName has been created on server $DbServerName"
    return $DbServerName
}

function Configure-MessagingBackend {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [Boolean] $IsStaging, 
        [Parameter(Mandatory = $true)] [String] $StorageAccountName,
        [Parameter(Mandatory = $true)] [String] $DBConnStrValue
    )

    $storageAccountKey = Get-AzureStorageKey $StorageAccountName
    $storageKey = $storageAccountKey.Primary
    $storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$StorageAccountName;AccountKey=$storageKey"
 
    $appSettings = @{
        "MessagesStorage" = "$storageConnectionString"
    } 
    $connectionStringInfo = @{
        Name = "BackendDb"; Type = "SQLAzure"; ConnectionString = $dbConnStrValue
    }

    if ($IsStaging -eq $true) {
        Set-AzureWebsite -Name $WebSiteName -slot staging -AppSettings $appSettings -ConnectionStrings $connectionStringInfo 
        Write-Host "configuring staging slot for $WebSiteName"
        azure site scale instances --instances 1 --size small --slot staging $WebSiteName
    }
    else {
        Set-AzureWebsite -Name $WebSiteName -AppSettings $appSettings -ConnectionStrings $connectionStringInfo
        Write-Host "configuring production slot for $WebSiteName"
        azure site scale instances --instances 1 --size small $WebSiteName
    }
}



Create-StorageAccount $config.storageAccountName
Create-StorageAccount $config.stagingStorageAccountName

$dbConStrValue = Get-BackendDatabase $config.databaseName
$stagingDBConStrValue = Get-BackendDatabase $config.stagingDatabaseName

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

Configure-MessagingBackend $false $config.storageAccountName $dbConStrValue
Configure-MessagingBackend $true $config.stagingStorageAccountName $stagingDBConStrValue 

Write-Host "URL: http://$WebSiteName.azurewebsites.net"
Write-Host "creation and configuration is done"

return @{Url="http://$WebSiteName.azurewebsites.net"; StagingUrl="http://$WebSiteName-staging.azurewebsites.net"}

