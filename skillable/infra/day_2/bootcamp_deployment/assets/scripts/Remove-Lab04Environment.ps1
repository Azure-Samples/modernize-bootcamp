[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [ValidatePattern('(?-i)^(?!.*--)[a-z0-9][a-z0-9-]{1,16}[a-z0-9]$')]
    [string]$Prefix,

    [Parameter(Mandatory)]
    [ValidatePattern('(?-i)^[a-z0-9]{8}$')]
    [string]$Suffix
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or later is required.'
}

$PSNativeCommandUseErrorActionPreference = $true
az account set --subscription $SubscriptionId

$resourceGroups = @(
    "rg-$Prefix-global-$Suffix"
    "rg-$Prefix-secondary-$Suffix"
    "rg-$Prefix-primary-$Suffix"
    "rg-$Prefix-bootstrap-$Suffix"
)

Write-Host 'The following exact resource groups are in cleanup scope:'
$resourceGroups | ForEach-Object { Write-Host " - $_" }

foreach ($resourceGroup in $resourceGroups) {
    $exists = az group exists --name $resourceGroup
    if ($exists -eq 'true' -and $PSCmdlet.ShouldProcess($resourceGroup, 'Delete Azure resource group')) {
        az group delete --name $resourceGroup --yes
    }
}

Write-Host 'Lab 04 Azure resource-group cleanup completed.'
