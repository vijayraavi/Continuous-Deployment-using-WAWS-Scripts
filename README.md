Continuous-Deployment-using-WAWS-Scripts
========================================

This repo contains Powershell scripts to demonstrate Continuous Deployment using Windows Azure Web Sites.
The examples are based on the following solution structure:

[PLACE HOLDER Solution Image]

- The frontend links to the backend using application settings
- The backend links to the storage account using application settings and uses a connection string to refer to the SQL database

All scripts are PowerShell cmdlets and therefore it was the intention to use the Windows Azure PowerShell scripts whenever possible. However as of March 2014, the Windows Azure PowerShell scripts were lacking the functionality to easily configure the Web Site scale mode (free, shared and standard) as well as the instances size of the dedicated Web Space. Therefore the scripts are using the azure site scale CLI commands to define the scale mode and to define the Web Space instance size and number:

    azure site scale mode --mode standard <website name>
    
    azure site scale instances --instances 4 --size small WebsiteName

Mixing PowerShell cmdlets and CLI scripts require some additional thoughts to deal with errors. CLI tools log errors to an azure.err file in the current directory, while PowerShell allows us to use exception handling using try/catch clauses. Since we’re mixing the two tools, we have to combine the two methods for error handling: For identifying CLI errors, we basically delete the azure.err (if it exists) and check if at the end of the script a new azure.err file has been created. If this is the case, we have an issue with one of our CLI commands. Detecting PowerShell issues is easier: Since we put the script body within a try clause, PowerShell exceptions will be automatically handled by the catch class. The below PowerShell script does exactly this, we just have to place our actual script commands at the position designated as [script body]:

    if ((Test-Path "azure.err") -eq $True) {
    	Write-Host "azure.err will be deleted"
    	del azure.err
    }
    try{
    	# start of script body
    	[script body]
    	# end of script body 
    	if ((Test-Path "azure.err") -eq $True) {
    		Write-Host "CLI ERRORS - check azure.err for details on errors"
    	}
    	else {
    		Write-Host “CLI & POWERSHELL SUCCESS"	
    	}
    }
    catch {
    	Write-Host "POWERSHELL ERROR - Azure PowerShell command terminated an error:”	Write-Host $_
    }

## Creating and configuring the Web Sites ##
The Create-MessagingSolution.ps1 script represents the top level script that creates and configures all Web Sites and resources. It requires the following parameters:

- **AzureSubscription** The name of the subscription where the solution should be deployed to. (Use azure account list to see a list of imported subscriptions)
- **DCLocation** The name of the data center location (e.g. “West Europe”)
- **FrontendReleaseName** The release branch name for the frontend (e.g. V2)
- **BackendReleaseName** The release branch name for the backend (e.g. V4)
- **DeleteExistingWebSites** Defines if existing Web Site instances will be deleted. If set to $True, existing Web Sites (staging and production) will be deleted before the creation and configuration of new instances. If set to $False, the script won’t delete existing Web Site instances but will reconfigure them.
- **CreateNewDatabase** Defines whether a new database and database server should be created or an existing one should be used. If set to $True, the script creates two new databases on two new database servers (one for production and one for staging). If set to $False, the script searches the database servers within the specified datacenter location (DCLocation parameter) for the existing databases. It aborts if the databases can’t be found.

**Example calls:**

    .\Create-MessagingSolution.ps1 <subscriptionname> "West Europe" V3 V6 $True $True
- creates the production and staging Web Sites for frontend V3 and backend V6 in West Europe
- if the Web Sites already exist, it will delete and recreate them
- creates two storage accounts (if they don’t already exist
- creates two SQL databases on two different database servers (one for production and for staging)

    .\Create-MessagingSolution.ps1 <subscriptionname> "West Europe" V3 V6 $False $False

- creates the production and staging Web Sites for frontend V3 and backend V6 in West Europe
- it doesn’t delete already existing Web Sites for the frontend V3 and backend V6 releases
- creates two storage accounts (if they don’t already exist)
- searches for existing databases within the database servers that belong to our subscription and are located in the “Western Europe” datacenter 
- it will abort if the databases can’t be found

## Creating a new component ##
The CreatePostUpdateScripts.ps1 script creates the post_update hook bash script for a new git repository. Simply copy the generated post_update script into the hook directory of the components git server repository. The post_update hook creation script requires the following parameters:

- **ComponentName** The name of the component. This must match the component name and naming convention used to create the corresponding Web Sites. Within these examples, the naming convention for the Web Sites is [ComponentName]-[RealeaseName]
- **GitUserName** The git user name that is configured to publish to the Web Site repository
- **GitPassword** The corresponding password

The following two calls create the update hooks for the two components of our messaging solution (MsgSolCB-Frontend and MsgSolCB-Backend):

    .\CreatePostUpdateScripts.ps1 MsgSolCB-Frontend UserName PassWord
    .\CreatePostUpdateScripts.ps1 MsgSolCB-Backend UserName PassWord
Once the scripts have been placed into the hook folder of the respective git server repository, each check-in will trigger the deployment to the respective Web Site.

## Swapping a Web Site ##
The Swap-WebSite.ps1 script can be used to swap the staging and the production slots while preserving the setting of the slot (old production settings remain with the new production slot, old staging settings remain with the new staging slot). The script requires the following Parameters:
- **AzureSubscription** The name of the subscription where the solution should be deployed to. (Use azure account list to see a list of imported subscriptions)
- **WebSiteName** The name of the Web Site to be swapped
The following call swaps MsgSolCB-Frontend-V3 with MsgSolCB-Frontend-V3(staging) while preserving the production and staging settings:
    .\Swap-WebSite.ps1 <subscriptionname> MsgSolCB-Frontend-V3










