param (
    [Parameter(Mandatory = $true)] [String] $ComponentName,
    [Parameter(Mandatory = $true)] [String] $GitUserName,
    [Parameter(Mandatory = $true)] [String] $GitPassword
)

Write-Host "create post-update hook for $ComponentName"
"#!/bin/sh
branch=`$(echo `$1  awk -F'/' '{print `$3}')
# Web Site naming convention: <componentname>-<releasename>-staging
gitcmd=`"git push https://$GitUserName`:$GitPassword@$ComponentName-`$branch-staging.scm.azurewebsites.net:443/$ComponentName-`$branch.git +`$branch:master`"
if [ ! -f `$1 ]; then
	echo `"Branch $branch was deleted!`"
else
	echo `"Branch $branch will be pushed`"
	`$gitcmd
fi" |  
Set-Content .\post-update.$ComponentName
Write-Host "`npost-update hook has been stored in .\post-update.$ComponentName" 
Write-Host "rename to post.update and copy to <server_repository>/hooks`n"