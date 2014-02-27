param (
    [Parameter(Mandatory = $true)] [String] $DCLocation,
    [Parameter(Mandatory = $true)] [String] $WebSiteName,
    [Parameter(Mandatory = $true)] [String] $ClientIP
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
        Write-Host "create staging storage account $storageAccountName in $DCLocation"
        azure storage account create --label $storageAccountName --location `"$DCLocation`" $storageAccountName
    }
    else {
        Write-Host "storage $storageAccountName already exists"
    }      
}

function Create-BackendDatabase {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [String] $AppDatabaseName 
    )

    $dbServerName = .\Create-SQLDatabase $DCLocation $AppDatabaseName $ClientIP $config.dbUsername $config.dbPassword

    Write-Host "Database $AppDatabaseName has been created on server $dbServerName"
    # Create connection string for database 
    $appDBConnStr  = "Server=tcp:$dbServerName.database.windows.net,1433;Database=$AppDatabaseName;"  
    $appDBConnStr += "User ID=" + $config.dbUsername + "@$dbServerName;Password=" + $config.dbPassword + ";Trusted_Connection=False;Encrypt=True;Connection Timeout=30;" 

    return $appDBConnStr
}

function Configure-MessagingBackend {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)] [Boolean] $IsStaging, 
        [Parameter(Mandatory = $true)] [String] $StorageAccountName,
        [Parameter(Mandatory = $true)] [String] $DBConnStrValue
    )



    $cliSlotOption =$null
    $slotName =$null
    if ($IsStaging -eq $true) {
        $cliSlotOption = "--slot"
        $slotName = "staging"
    }

    Write-Host "configuring $WebSiteName"
    azure site scale instances --instances 2 --size small $cliSlotOption $slotName $WebSiteName

    Write-Host "configuring application settings for $WebSiteName"
    $storageAccountKey = Get-AzureStorageKey $StorageAccountName
    $storageKey = $storageAccountKey.Primary
    $storageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$StorageAccountName;AccountKey=$storageKey"
 
    $appSettings = @{
        "MessagesStorage" = "$storageConnectionString"
    } 

    if ($IsStaging -eq $true) {
        Set-AzureWebsite -Name $WebSiteName -slot $slotName -AppSettings $appSettings
    }
    else {
        Set-AzureWebsite -Name $WebSiteName -AppSettings $appSettings
    }

    Write-Host "configuring connection strings for $WebSiteName"
    azure site connectionstring add "BackendDb" $dbConnStrValue "SQLAzure" $cliSlotOption $slotName $WebSiteName
}



Create-StorageAccount $config.storageAccountName
Create-StorageAccount $config.stagingStorageAccountName

$dbConStrValue = Create-BackendDatabase $config.databaseName
$stagingDBConStrValue = Create-BackendDatabase $config.stagingDatabaseName

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

Configure-MessagingBackend $false $config.storageAccountName $dbConStrValue
Configure-MessagingBackend $true $config.stagingStorageAccountName $stagingDBConStrValue 

Write-Host "URL: http://$WebSiteName.azurewebsites.net"
Write-Host "creation and configuration is done"

return @{Url="http://$WebSiteName.azurewebsites.net"; StagingUrl="http://$WebSiteName-staging.azurewebsites.net"}

