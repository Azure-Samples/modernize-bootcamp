[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [ValidateNotNullOrEmpty()]
    [string]$BootstrapResourceGroup,

    [ValidateNotNullOrEmpty()]
    [string]$PrimaryResourceGroup,

    [ValidateNotNullOrEmpty()]
    [string]$SecondaryResourceGroup,

    [ValidateNotNullOrEmpty()]
    [string]$GlobalResourceGroup,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$BootstrapDeploymentName,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$PrimaryDeploymentName,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$SecondaryDeploymentName,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$GlobalDeploymentName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw "Required command 'az' was not found on PATH."
}

$resourceGroupPrefixes = [ordered]@{
    Bootstrap = 'rg-caldova-lab04-bootstrap-'
    Primary = 'rg-caldova-lab04-primary-'
    Secondary = 'rg-caldova-lab04-secondary-'
    Global = 'rg-caldova-lab04-global-'
}
$deploymentOutputContracts = @{
    Bootstrap = @(
        'codeBuildIdentityName',
        'codeBuildClientId',
        'codeBuildPrincipalId',
        'codeDeploymentIdentityName',
        'codeDeploymentClientId',
        'codeDeploymentPrincipalId',
        'runtimeIdentityName',
        'runtimeIdentityId',
        'runtimeIdentityClientId',
        'runtimeIdentityPrincipalId'
    )
    Primary = @('containerRegistryName')
    Secondary = @(
        'containerAppName',
        'containerAppsEnvironmentId',
        'retailDatabaseName'
    )
    Global = @('frontDoorProfileId')
}

function Resolve-Lab04ResourceGroups {
    param(
        [string]$Bootstrap,
        [string]$Primary,
        [string]$Secondary,
        [string]$Global
    )

    $provided = [ordered]@{
        Bootstrap = $Bootstrap
        Primary = $Primary
        Secondary = $Secondary
        Global = $Global
    }
    $resourceGroupNames = @(
        az group list `
            --subscription $SubscriptionId `
            --query '[].name' `
            --output tsv
    )
    $resolved = [ordered]@{}
    foreach ($entry in $resourceGroupPrefixes.GetEnumerator()) {
        $override = $provided[$entry.Key]
        if (-not [string]::IsNullOrWhiteSpace($override)) {
            if (-not $override.StartsWith($entry.Value, [StringComparison]::OrdinalIgnoreCase)) {
                throw "$($entry.Key) resource group '$override' must start with '$($entry.Value)'."
            }
            if ($override -notin $resourceGroupNames) {
                throw "$($entry.Key) resource-group override '$override' was not found in subscription '$SubscriptionId'."
            }
            $resolved[$entry.Key] = $override
            continue
        }

        $matches = @(
            $resourceGroupNames |
                Where-Object {
                    $_.StartsWith($entry.Value, [StringComparison]::OrdinalIgnoreCase)
                }
        )
        if ($matches.Count -eq 0) {
            throw "No $($entry.Key) resource group starts with '$($entry.Value)' in subscription '$SubscriptionId'."
        }
        if ($matches.Count -gt 1) {
            throw "Multiple $($entry.Key) resource groups start with '$($entry.Value)': $($matches -join ', '). Supply -$($entry.Key)ResourceGroup to select one."
        }
        $resolved[$entry.Key] = $matches[0]
    }
    return [pscustomobject]$resolved
}

function ConvertFrom-DeploymentOutputs {
    param(
        [Parameter(Mandatory)]
        [object]$Outputs
    )

    $values = @{}
    foreach ($output in $Outputs.PSObject.Properties) {
        $values[$output.Name] = $output.Value.value
    }
    return $values
}

function Test-RequiredOutputs {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Outputs,

        [Parameter(Mandatory)]
        [string[]]$RequiredOutputs
    )

    if ($null -eq $Outputs) {
        return $false
    }
    foreach ($name in $RequiredOutputs) {
        $property = $Outputs.PSObject.Properties[$name]
        if (
            $null -eq $property -or
            [string]::IsNullOrWhiteSpace("$($property.Value.value)")
        ) {
            return $false
        }
    }
    return $true
}

function Get-ResourceGroupDeployment {
    param(
        [Parameter(Mandatory)][string]$Role,
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string[]]$RequiredOutputs,
        [string]$DeploymentName
    )

    if (-not [string]::IsNullOrWhiteSpace($DeploymentName)) {
        $deployment = az deployment group show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $DeploymentName `
            --output json | ConvertFrom-Json
        if ($deployment.properties.provisioningState -ne 'Succeeded') {
            throw "$Role deployment '$DeploymentName' in resource group '$ResourceGroup' is not in Succeeded state."
        }
        if (
            -not (Test-RequiredOutputs `
                -Outputs $deployment.properties.outputs `
                -RequiredOutputs $RequiredOutputs)
        ) {
            throw "$Role deployment '$DeploymentName' in resource group '$ResourceGroup' does not contain the required outputs: $($RequiredOutputs -join ', ')."
        }
        return $deployment
    }

    $deploymentSummaries = @(
        az deployment group list `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --query "[?properties.provisioningState=='Succeeded']" `
            --output json | ConvertFrom-Json
    )
    $matches = @()
    foreach ($summary in $deploymentSummaries) {
        $candidate = az deployment group show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $summary.name `
            --output json | ConvertFrom-Json
        if (
            Test-RequiredOutputs `
                -Outputs $candidate.properties.outputs `
                -RequiredOutputs $RequiredOutputs
        ) {
            $matches += $candidate
        }
    }
    if ($matches.Count -eq 0) {
        throw "No successful $Role deployment in resource group '$ResourceGroup' contains the required outputs: $($RequiredOutputs -join ', ')."
    }

    return @(
        $matches |
            Sort-Object `
                @{ Expression = { [datetime]$_.properties.timestamp }; Descending = $true },
                @{ Expression = { $_.name }; Descending = $true }
    )[0]
}

function Get-RequiredDeploymentParameter {
    param(
        [Parameter(Mandatory)][object]$Deployment,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Role
    )

    $parameters = $Deployment.properties.parameters
    $property = if ($null -ne $parameters) {
        $parameters.PSObject.Properties[$Name]
    }
    else {
        $null
    }
    $value = if ($property) {
        $property.Value.value
    }
    else {
        $null
    }
    if ([string]::IsNullOrWhiteSpace("$value")) {
        throw "$Role deployment '$($Deployment.name)' does not contain required parameter '$Name'."
    }
    return [string]$value
}

$account = az account show `
    --subscription $SubscriptionId `
    --query '{id:id,tenantId:tenantId}' `
    --output json |
    ConvertFrom-Json
if ($account.id -ne $SubscriptionId) {
    throw "Azure CLI selected subscription '$($account.id)' instead of '$SubscriptionId'."
}
$resolvedResourceGroups = Resolve-Lab04ResourceGroups `
    -Bootstrap $BootstrapResourceGroup `
    -Primary $PrimaryResourceGroup `
    -Secondary $SecondaryResourceGroup `
    -Global $GlobalResourceGroup
$BootstrapResourceGroup = $resolvedResourceGroups.Bootstrap
$PrimaryResourceGroup = $resolvedResourceGroups.Primary
$SecondaryResourceGroup = $resolvedResourceGroups.Secondary
$GlobalResourceGroup = $resolvedResourceGroups.Global

$deployments = [ordered]@{
    Bootstrap = Get-ResourceGroupDeployment `
        -Role Bootstrap `
        -ResourceGroup $BootstrapResourceGroup `
        -RequiredOutputs $deploymentOutputContracts.Bootstrap `
        -DeploymentName $BootstrapDeploymentName
    Primary = Get-ResourceGroupDeployment `
        -Role Primary `
        -ResourceGroup $PrimaryResourceGroup `
        -RequiredOutputs $deploymentOutputContracts.Primary `
        -DeploymentName $PrimaryDeploymentName
    Secondary = Get-ResourceGroupDeployment `
        -Role Secondary `
        -ResourceGroup $SecondaryResourceGroup `
        -RequiredOutputs $deploymentOutputContracts.Secondary `
        -DeploymentName $SecondaryDeploymentName
    Global = Get-ResourceGroupDeployment `
        -Role Global `
        -ResourceGroup $GlobalResourceGroup `
        -RequiredOutputs $deploymentOutputContracts.Global `
        -DeploymentName $GlobalDeploymentName
}

$prefixes = @{}
$suffixes = @{}
foreach ($entry in $deployments.GetEnumerator()) {
    $prefixes[$entry.Key] = Get-RequiredDeploymentParameter `
        -Deployment $entry.Value `
        -Name prefix `
        -Role $entry.Key
    $suffixes[$entry.Key] = Get-RequiredDeploymentParameter `
        -Deployment $entry.Value `
        -Name suffix `
        -Role $entry.Key
}
$distinctPrefixes = @($prefixes.Values | Sort-Object -Unique)
$distinctSuffixes = @($suffixes.Values | Sort-Object -Unique)
if ($distinctPrefixes.Count -ne 1 -or $distinctSuffixes.Count -ne 1) {
    $selection = $deployments.GetEnumerator() | ForEach-Object {
        "$($_.Key)=$($_.Value.name) (prefix=$($prefixes[$_.Key]), suffix=$($suffixes[$_.Key]))"
    }
    throw "Selected deployments do not belong to one Lab 04 boundary: $($selection -join '; '). Use the per-role deployment-name overrides to select a consistent set."
}

$bootstrapOutputs = ConvertFrom-DeploymentOutputs `
    -Outputs $deployments.Bootstrap.properties.outputs
$primaryOutputs = ConvertFrom-DeploymentOutputs `
    -Outputs $deployments.Primary.properties.outputs
$secondaryOutputs = ConvertFrom-DeploymentOutputs `
    -Outputs $deployments.Secondary.properties.outputs
$globalOutputs = ConvertFrom-DeploymentOutputs `
    -Outputs $deployments.Global.properties.outputs

$result = [ordered]@{
    SubscriptionId = [string]$account.id
    TenantId = [string]$account.tenantId
    Deployments = [ordered]@{}
    Values = [ordered]@{
        LAB04_BOOTSTRAP_RESOURCE_GROUP = $BootstrapResourceGroup
        LAB04_PRIMARY_RESOURCE_GROUP = $PrimaryResourceGroup
        LAB04_SECONDARY_RESOURCE_GROUP = $SecondaryResourceGroup
        LAB04_GLOBAL_RESOURCE_GROUP = $GlobalResourceGroup
        LAB04_PREFIX = $distinctPrefixes[0]
        LAB04_SUFFIX = $distinctSuffixes[0]
        LAB06_BUILD_AZURE_CLIENT_ID = $bootstrapOutputs.codeBuildClientId
        LAB06_BUILD_AZURE_PRINCIPAL_ID = $bootstrapOutputs.codeBuildPrincipalId
        LAB06_BUILD_IDENTITY_NAME = $bootstrapOutputs.codeBuildIdentityName
        LAB06_DEPLOY_AZURE_CLIENT_ID = $bootstrapOutputs.codeDeploymentClientId
        LAB06_DEPLOY_AZURE_PRINCIPAL_ID = $bootstrapOutputs.codeDeploymentPrincipalId
        LAB06_DEPLOYMENT_IDENTITY_NAME = $bootstrapOutputs.codeDeploymentIdentityName
        LAB06_RUNTIME_IDENTITY_NAME = $bootstrapOutputs.runtimeIdentityName
        LAB06_RUNTIME_IDENTITY_RESOURCE_ID = $bootstrapOutputs.runtimeIdentityId
        LAB06_RUNTIME_IDENTITY_CLIENT_ID = $bootstrapOutputs.runtimeIdentityClientId
        LAB06_RUNTIME_IDENTITY_PRINCIPAL_ID = $bootstrapOutputs.runtimeIdentityPrincipalId
        LAB06_CONTAINER_REGISTRY_NAME = $primaryOutputs.containerRegistryName
        LAB06_CONTAINER_APP_NAME = $secondaryOutputs.containerAppName
        LAB05_RETAIL_DATABASE_NAME = $secondaryOutputs.retailDatabaseName
        LAB04_CONTAINER_APPS_ENVIRONMENT_ID = $secondaryOutputs.containerAppsEnvironmentId
        FRONT_DOOR_PROFILE_ID = $globalOutputs.frontDoorProfileId
    }
}

$resourceGroups = @{
    Bootstrap = $BootstrapResourceGroup
    Primary = $PrimaryResourceGroup
    Secondary = $SecondaryResourceGroup
    Global = $GlobalResourceGroup
}
foreach ($entry in $deployments.GetEnumerator()) {
    $result.Deployments[$entry.Key] = [ordered]@{
        ResourceGroup = $resourceGroups[$entry.Key]
        Name = [string]$entry.Value.name
        Timestamp = [string]$entry.Value.properties.timestamp
    }
}

$result | ConvertTo-Json -Depth 5
