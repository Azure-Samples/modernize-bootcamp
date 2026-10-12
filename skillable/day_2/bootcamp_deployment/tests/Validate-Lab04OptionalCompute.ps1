[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$main = Get-Content (Join-Path $projectRoot 'infra\main.bicep') -Raw
$parameters = Get-Content (Join-Path $projectRoot 'infra\main.parameters.json') -Raw
$bootstrap = Get-Content (Join-Path $projectRoot 'infra\lab04\complete\bootstrap.bicep') -Raw
$primary = Get-Content (Join-Path $projectRoot 'infra\lab04\complete\primary.bicep') -Raw
$network = Get-Content (Join-Path $projectRoot 'infra\lab04\complete\modules\regional-network.bicep') -Raw
$virtualMachines = Get-Content (Join-Path $projectRoot 'infra\lab04\complete\modules\virtual-machines.bicep') -Raw
$preprovision = Get-Content (Join-Path $projectRoot 'infra\hooks\preprovision.ps1') -Raw
$directDeployment = Get-Content (Join-Path $projectRoot 'infra\Deploy-Lab04.ps1') -Raw

$failures = [System.Collections.Generic.List[string]]::new()

function Assert-Contract {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )

    if (-not $Condition) {
        $failures.Add($Message)
    }
}

Assert-Contract (
    $main -match "param deployVirtualMachines string = 'false'" -and
    $main -match "var deployVirtualMachinesEnabled = deployVirtualMachines == 'true'" -and
    $main -match "param vmAdminPassword string = ''"
) 'main.bicep must keep the VM password optional and disable VM deployment by default.'
Assert-Contract (
    ([regex]::Matches($main, 'deployVirtualMachines:\s*deployVirtualMachinesEnabled')).Count -eq 2
) 'main.bicep must pass the compute flag to the bootstrap and primary modules.'
Assert-Contract (
    $parameters -match '\$\{LAB04_DEPLOY_VIRTUAL_MACHINES=false\}' -and
    $parameters -match '\$\{LAB04_VM_ADMIN_PASSWORD=\}'
) 'AZD parameters must default compute to false and allow an omitted VM password.'
Assert-Contract (
    $bootstrap -match "vmUsernameSecret[\s\S]*?if \(deployVirtualMachines\)" -and
    $bootstrap -match "vmPasswordSecret[\s\S]*?if \(deployVirtualMachines\)"
) 'VM credential secrets must only deploy with the optional VMs.'
Assert-Contract (
    $primary -match "module machines[\s\S]*?if \(deployVirtualMachines\)" -and
    $primary -match "module bastion[\s\S]*?if \(deployVirtualMachines\)" -and
    $primary -match 'enableVirtualMachines:\s*deployVirtualMachines'
) 'The primary module must gate VMs, Bastion, and their network resources with one flag.'
Assert-Contract (
    $network -match "vmNsg[\s\S]*?if \(enablePrimaryServices && enableVirtualMachines\)" -and
    $network -match "bastionSubnet[\s\S]*?if \(enablePrimaryServices && enableVirtualMachines\)" -and
    $network -match "vmSubnet[\s\S]*?if \(enablePrimaryServices && enableVirtualMachines\)"
) 'The VM NSG and VM/Bastion subnets must be omitted when optional compute is disabled.'
Assert-Contract (
    $virtualMachines -match '@minLength\(12\)[\s\S]*?@maxLength\(72\)[\s\S]*?param adminPassword string'
) 'The conditional VM module must require a valid password when it is deployed.'
Assert-Contract (
    $preprovision -match "LAB04_DEPLOY_VIRTUAL_MACHINES.+?'false'" -and
    $preprovision -match 'if \(\$deployVirtualMachines -and -not \(Get-AzdValue -Name LAB04_VM_ADMIN_PASSWORD\)\)' -and
    $preprovision -match "keyvault secret list[\s\S]*?vm-admin-password" -and
    $preprovision -match 'if \(-not \$password\)'
) 'AZD must manage a VM password only when compute is enabled and generate one when an existing vault has no VM secret.'
Assert-Contract (
    $directDeployment -match '\[switch\]\$DeployVirtualMachines' -and
    $directDeployment -match 'if \(\$DeployVirtualMachines -and -not \$VmAdminPassword\)' -and
    $directDeployment -match 'deployVirtualMachines=\$\(\$DeployVirtualMachines\.IsPresent'
) 'Direct deployment must expose an opt-in switch and prompt for a password only when enabled.'

if ($failures.Count -gt 0) {
    throw "Lab 04 optional compute validation failed:`n- $($failures -join "`n- ")"
}

Write-Host 'Lab 04 optional compute contracts are valid.'
