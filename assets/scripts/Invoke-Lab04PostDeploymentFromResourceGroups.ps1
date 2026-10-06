[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SubscriptionId,

    [ValidateNotNullOrEmpty()]
    [string]$BootstrapResourceGroup,

    [ValidateNotNullOrEmpty()]
    [string]$SecondaryResourceGroup,

    [ValidateNotNullOrEmpty()]
    [string]$GlobalResourceGroup,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$BootstrapDeploymentName,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$SecondaryDeploymentName,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$GlobalDeploymentName,

    [ValidateLength(1, 64)]
    [ValidatePattern('^[a-zA-Z0-9._()\-]+$')]
    [string]$SqlMiDeploymentName,

    [string]$BacpacPath,

    [switch]$ReplaceExistingDatabase,

    [switch]$DiscoveryOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

$resourceGroupPrefixes = [ordered]@{
    Bootstrap = 'rg-caldova-lab04-bootstrap-'
    Secondary = 'rg-caldova-lab04-secondary-'
    Global = 'rg-caldova-lab04-global-'
}
$deploymentOutputContracts = @{
    Bootstrap = @('runtimeIdentityClientId')
    Secondary = @(
        'containerAppName',
        'containerAppsEnvironmentId',
        'databaseType',
        'retailDatabaseName',
        'sqlMiNetworkSecurityGroupName'
    )
    Global = @(
        'frontDoorEndpointHostName',
        'frontDoorOriginId',
        'privateLinkRequestMessage'
    )
    SqlMi = @(
        'managedInstanceName',
        'managedInstanceFqdn',
        'managedInstancePublicEndpoint',
        'managedDatabaseName'
    )
}

foreach ($command in @('az')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found on PATH."
    }
}

$script:Lab04SqlPackageVersion = '170.5.96'
$script:Lab04SqlPackageFeed = 'https://api.nuget.org/v3/index.json'

function Test-Lab04PublicIPv4Address {
    param([Parameter(Mandatory)][string]$IpAddress)

    $parsedAddress = $null
    return (
        [Net.IPAddress]::TryParse($IpAddress, [ref]$parsedAddress) -and
        $parsedAddress.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
        $parsedAddress.ToString() -eq $IpAddress
    )
}

function New-Lab04DatabaseImportRuleName {
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$EnvironmentName,
        [Parameter(Mandatory)][ValidateSet('sqlMi')][string]$DatabaseMode
    )

    $value = "$SubscriptionId|$EnvironmentName|$DatabaseMode".ToLowerInvariant()
    $bytes = [Text.Encoding]::UTF8.GetBytes($value)
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }
    $hash = [BitConverter]::ToString($hashBytes).Replace('-', '').ToLowerInvariant()
    return "AllowBacpacImport-$($hash.Substring(0, 24))"
}

function Get-Lab04SqlPackageExecutableName {
    if ([IO.Path]::DirectorySeparatorChar -eq '\') {
        return 'sqlpackage.exe'
    }
    return 'sqlpackage'
}

function Get-Lab04SqlPackageCachePath {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $azureRoot = Join-Path $ProjectRoot '.azure'
    $toolsRoot = Join-Path $azureRoot 'tools'
    $sqlPackageRoot = Join-Path $toolsRoot 'sqlpackage'
    return Join-Path $sqlPackageRoot $script:Lab04SqlPackageVersion
}

function Assert-Lab04SqlPackageVersion {
    param([Parameter(Mandatory)][string]$ExecutablePath)

    if (-not (Test-Path -LiteralPath $ExecutablePath -PathType Leaf)) {
        throw "SqlPackage executable was not found at '$ExecutablePath'."
    }
    $reportedVersion = (& $ExecutablePath /Version).ToString().Trim()
    if ($LASTEXITCODE -ne 0) {
        throw "SqlPackage at '$ExecutablePath' failed its version check with exit code $LASTEXITCODE."
    }
    if ($reportedVersion -notmatch "^$([regex]::Escape($script:Lab04SqlPackageVersion))(?:\.0)?$") {
        throw "SqlPackage at '$ExecutablePath' reported version '$reportedVersion'; expected '$script:Lab04SqlPackageVersion'."
    }
}

function Resolve-Lab04SqlPackage {
    param([Parameter(Mandatory)][string]$ProjectRoot)

    $cachePath = Get-Lab04SqlPackageCachePath -ProjectRoot $ProjectRoot
    $executableName = Get-Lab04SqlPackageExecutableName
    $executablePath = Join-Path $cachePath $executableName
    if (Test-Path -LiteralPath $executablePath -PathType Leaf) {
        Assert-Lab04SqlPackageVersion -ExecutablePath $executablePath
        return $executablePath
    }
    if (Test-Path -LiteralPath $cachePath) {
        throw "The SqlPackage cache at '$cachePath' is incomplete. Remove that version directory and rerun."
    }
    if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
        throw "Required command 'dotnet' was not found on PATH. Install the .NET SDK and rerun."
    }

    $toolsRoot = Split-Path -Parent $cachePath
    $null = New-Item -ItemType Directory -Path $toolsRoot -Force
    $temporaryPath = Join-Path `
        $toolsRoot `
        ".install-$([guid]::NewGuid().ToString('N'))"
    try {
        & dotnet tool install Microsoft.SqlPackage `
            --tool-path $temporaryPath `
            --version $script:Lab04SqlPackageVersion `
            --add-source $script:Lab04SqlPackageFeed `
            --ignore-failed-sources `
            --allow-roll-forward | Write-Host
        if ($LASTEXITCODE -ne 0) {
            throw "Installing Microsoft.SqlPackage $script:Lab04SqlPackageVersion failed with exit code $LASTEXITCODE."
        }

        $temporaryExecutablePath = Join-Path $temporaryPath $executableName
        Assert-Lab04SqlPackageVersion `
            -ExecutablePath $temporaryExecutablePath
        if (Test-Path -LiteralPath $cachePath) {
            if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
                throw "Another SqlPackage installation created an incomplete cache at '$cachePath'."
            }
            Assert-Lab04SqlPackageVersion -ExecutablePath $executablePath
            return $executablePath
        }
        try {
            Move-Item -LiteralPath $temporaryPath -Destination $cachePath
        }
        catch {
            if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
                throw
            }
            Assert-Lab04SqlPackageVersion -ExecutablePath $executablePath
            return $executablePath
        }
        Assert-Lab04SqlPackageVersion -ExecutablePath $executablePath
        return $executablePath
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Recurse -Force
        }
    }
}

function Get-StandaloneToolCacheRoot {
    $basePath = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::LocalApplicationData
    )
    if ([string]::IsNullOrWhiteSpace($basePath)) {
        $basePath = Join-Path $HOME '.cache'
    }
    return Join-Path $basePath 'modernize-bootcamp'
}

function Resolve-StandaloneBacpacPath {
    param([string]$OverridePath)

    if (-not [string]::IsNullOrWhiteSpace($OverridePath)) {
        if (-not (Test-Path -LiteralPath $OverridePath -PathType Leaf)) {
            throw "The eShop BACPAC was not found at '$OverridePath'."
        }
        return (Resolve-Path -LiteralPath $OverridePath).Path
    }

    $candidates = [System.Collections.Generic.List[string]]::new()
    $candidates.Add((Join-Path $PSScriptRoot 'eshop.bacpac'))
    $candidates.Add((Join-Path (Join-Path $PSScriptRoot 'data') 'eshop.bacpac'))
    $currentDirectory = (Get-Location).Path
    $candidates.Add((Join-Path $currentDirectory 'eshop.bacpac'))
    $candidates.Add(
        (Join-Path (Join-Path $currentDirectory 'data') 'eshop.bacpac')
    )

    $ancestor = Get-Item -LiteralPath $PSScriptRoot
    while ($null -ne $ancestor) {
        $candidates.Add(
            (Join-Path (Join-Path $ancestor.FullName 'data') 'eshop.bacpac')
        )
        $ancestor = $ancestor.Parent
    }
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }
    throw "The eShop BACPAC was not found beside the script, in a local or ancestor 'data' directory, or under the current working directory. Supply -BacpacPath."
}

function Resolve-Lab04ResourceGroups {
    param(
        [string]$Bootstrap,
        [string]$Secondary,
        [string]$Global
    )

    $provided = [ordered]@{
        Bootstrap = $Bootstrap
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
    param([Parameter(Mandatory)][object]$Outputs)

    $values = @{}
    foreach ($output in $Outputs.PSObject.Properties) {
        $values[$output.Name] = $output.Value.value
    }
    return $values
}

function Test-DeploymentOutputs {
    param(
        [AllowNull()][object]$Outputs,
        [Parameter(Mandatory)][string[]]$RequiredOutputs
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
            throw "$Role deployment '$DeploymentName' in '$ResourceGroup' is not in Succeeded state."
        }
        if (
            -not (Test-DeploymentOutputs `
                -Outputs $deployment.properties.outputs `
                -RequiredOutputs $RequiredOutputs)
        ) {
            throw "$Role deployment '$DeploymentName' is missing required outputs: $($RequiredOutputs -join ', ')."
        }
        return $deployment
    }

    $summaries = @(
        az deployment group list `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --query "[?properties.provisioningState=='Succeeded']" `
            --output json | ConvertFrom-Json
    )
    $matches = @()
    foreach ($summary in $summaries) {
        $candidate = az deployment group show `
            --subscription $SubscriptionId `
            --resource-group $ResourceGroup `
            --name $summary.name `
            --output json | ConvertFrom-Json
        if (
            Test-DeploymentOutputs `
                -Outputs $candidate.properties.outputs `
                -RequiredOutputs $RequiredOutputs
        ) {
            $matches += $candidate
        }
    }
    if ($matches.Count -eq 0) {
        throw "No successful $Role deployment in '$ResourceGroup' contains: $($RequiredOutputs -join ', ')."
    }
    return @(
        $matches |
            Sort-Object `
                @{ Expression = { [datetime]$_.properties.timestamp }; Descending = $true },
                @{ Expression = { $_.name }; Descending = $true }
    )[0]
}

function Get-DeploymentParameterValue {
    param(
        [Parameter(Mandatory)][object]$Deployment,
        [Parameter(Mandatory)][string]$Name
    )

    $parameters = $Deployment.properties.parameters
    if ($null -eq $parameters) {
        return $null
    }
    $property = $parameters.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value.value
}

function Assert-DeploymentBoundary {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Deployments)

    foreach ($parameterName in @('prefix', 'suffix')) {
        $values = @()
        foreach ($entry in $Deployments.GetEnumerator()) {
            $value = Get-DeploymentParameterValue `
                -Deployment $entry.Value `
                -Name $parameterName
            if (-not [string]::IsNullOrWhiteSpace("$value")) {
                $values += [string]$value
            }
        }
        $distinctValues = @($values | Sort-Object -Unique)
        if ($distinctValues.Count -gt 1) {
            throw "Selected deployments have inconsistent '$parameterName' values: $($distinctValues -join ', '). Use deployment-name overrides to select one application boundary."
        }
    }
}

function Add-CleanupFailure {
    param(
        [Parameter(Mandatory)][System.Collections.Generic.List[string]]$Failures,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][System.Management.Automation.ErrorRecord]$ErrorRecord
    )

    $Failures.Add("$Action failed: $($ErrorRecord.Exception.Message)")
}

function Approve-FrontDoorPrivateLink {
    param(
        [Parameter(Mandatory)][string]$EnvironmentId,
        [Parameter(Mandatory)][string]$OriginId,
        [Parameter(Mandatory)][string]$RequestMessage,
        [Parameter(Mandatory)][string]$EndpointHostName
    )

    $connectionApproved = $false
    for ($attempt = 1; $attempt -le 20; $attempt++) {
        $connections = @(
            az network private-endpoint-connection list `
                --subscription $SubscriptionId `
                --id $EnvironmentId `
                --output json | ConvertFrom-Json
        )
        $unknownPending = @(
            $connections | Where-Object {
                $_.properties.privateLinkServiceConnectionState.status -eq 'Pending' -and
                $_.properties.privateLinkServiceConnectionState.description -ne $RequestMessage
            }
        )
        if ($unknownPending.Count -gt 0) {
            throw 'Unknown pending private endpoint connection detected. No connection was approved.'
        }

        $expectedConnections = @(
            $connections | Where-Object {
                $_.properties.privateLinkServiceConnectionState.description -eq $RequestMessage -and
                $_.properties.privateLinkServiceConnectionState.status -in @('Pending', 'Approved')
            }
        )
        if ($expectedConnections.Count -gt 1) {
            throw 'Multiple private endpoint connections match the expected Front Door request.'
        }
        if ($expectedConnections.Count -eq 1) {
            $connection = $expectedConnections[0]
            if ($connection.properties.privateLinkServiceConnectionState.status -eq 'Pending') {
                az network private-endpoint-connection approve `
                    --subscription $SubscriptionId `
                    --id $connection.id `
                    --description $RequestMessage `
                    --output none
            }
            $status = az network private-endpoint-connection show `
                --subscription $SubscriptionId `
                --id $connection.id `
                --query properties.privateLinkServiceConnectionState.status `
                --output tsv
            if ($status -eq 'Approved') {
                $connectionApproved = $true
                break
            }
        }
        Start-Sleep -Seconds 15
    }
    if (-not $connectionApproved) {
        throw 'The expected Front Door Private Link request was not approved within five minutes.'
    }

    $originHostName = az resource show `
        --subscription $SubscriptionId `
        --ids $OriginId `
        --api-version 2024-02-01 `
        --query properties.hostName `
        --output tsv
    if ([string]::IsNullOrWhiteSpace($originHostName)) {
        throw 'The expected Front Door origin could not be verified.'
    }

    $endpointUri = "https://$EndpointHostName/"
    $lastProbeFailure = 'No HTTP response was received.'
    for ($attempt = 1; $attempt -le 60; $attempt++) {
        try {
            $response = Invoke-WebRequest `
                -Uri $endpointUri `
                -Method Get `
                -TimeoutSec 15 `
                -UseBasicParsing
            if ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400) {
                Write-Host "Front Door Private Link is approved and '$endpointUri' is ready."
                return
            }
            $lastProbeFailure = "HTTP $([int]$response.StatusCode)"
        }
        catch {
            $webResponse = $_.Exception.Response
            if ($webResponse) {
                $lastProbeFailure = "HTTP $([int]$webResponse.StatusCode)"
            }
            else {
                $lastProbeFailure = $_.Exception.Message
            }
        }
        Start-Sleep -Seconds 30
    }
    throw "Front Door endpoint '$endpointUri' did not become healthy within 30 minutes. Last probe: $lastProbeFailure"
}

function Set-ContainerAppDatabaseConfiguration {
    param(
        [Parameter(Mandatory)][string]$ResourceGroup,
        [Parameter(Mandatory)][string]$ContainerAppName,
        [Parameter(Mandatory)][string]$DatabaseFqdn,
        [Parameter(Mandatory)][string]$RetailDatabaseName,
        [Parameter(Mandatory)][string]$RuntimeIdentityClientId
    )

    $connectionString = "Server=tcp:$DatabaseFqdn,1433;Initial Catalog=$RetailDatabaseName;User Id=$RuntimeIdentityClientId;Authentication=Active Directory Managed Identity;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
    az containerapp update `
        --subscription $SubscriptionId `
        --resource-group $ResourceGroup `
        --name $ContainerAppName `
        --set-env-vars `
            "AZURE_CLIENT_ID=$RuntimeIdentityClientId" `
            "ConnectionStrings__StoreDbContext=$connectionString" `
        --output none

    $environment = az containerapp show `
        --subscription $SubscriptionId `
        --resource-group $ResourceGroup `
        --name $ContainerAppName `
        --query properties.template.containers[0].env `
        --output json | ConvertFrom-Json
    $clientIdSetting = @($environment | Where-Object name -EQ 'AZURE_CLIENT_ID')
    $connectionSetting = @(
        $environment |
            Where-Object name -EQ 'ConnectionStrings__StoreDbContext'
    )
    if (
        $clientIdSetting.Count -ne 1 -or
        $clientIdSetting[0].value -ne $RuntimeIdentityClientId -or
        $connectionSetting.Count -ne 1 -or
        $connectionSetting[0].value -ne $connectionString
    ) {
        throw "Container App database configuration verification failed for '$ContainerAppName'."
    }
}

$toolCacheRoot = Get-StandaloneToolCacheRoot

$account = az account show `
    --subscription $SubscriptionId `
    --query '{id:id,user:user.name}' `
    --output json | ConvertFrom-Json
if ($account.id -ne $SubscriptionId) {
    throw "Azure CLI selected subscription '$($account.id)' instead of '$SubscriptionId'."
}

$resourceGroups = Resolve-Lab04ResourceGroups `
    -Bootstrap $BootstrapResourceGroup `
    -Secondary $SecondaryResourceGroup `
    -Global $GlobalResourceGroup
$BootstrapResourceGroup = $resourceGroups.Bootstrap
$SecondaryResourceGroup = $resourceGroups.Secondary
$GlobalResourceGroup = $resourceGroups.Global

$bootstrapDeployment = Get-ResourceGroupDeployment `
    -Role Bootstrap `
    -ResourceGroup $BootstrapResourceGroup `
    -RequiredOutputs $deploymentOutputContracts.Bootstrap `
    -DeploymentName $BootstrapDeploymentName
$secondaryDeployment = Get-ResourceGroupDeployment `
    -Role Secondary `
    -ResourceGroup $SecondaryResourceGroup `
    -RequiredOutputs $deploymentOutputContracts.Secondary `
    -DeploymentName $SecondaryDeploymentName
$globalDeployment = Get-ResourceGroupDeployment `
    -Role Global `
    -ResourceGroup $GlobalResourceGroup `
    -RequiredOutputs $deploymentOutputContracts.Global `
    -DeploymentName $GlobalDeploymentName

$bootstrapOutputs = ConvertFrom-DeploymentOutputs `
    -Outputs $bootstrapDeployment.properties.outputs
$secondaryOutputs = ConvertFrom-DeploymentOutputs `
    -Outputs $secondaryDeployment.properties.outputs
$globalOutputs = ConvertFrom-DeploymentOutputs `
    -Outputs $globalDeployment.properties.outputs
if ([string]$secondaryOutputs.databaseType -cne 'sqlMi') {
    throw "The standalone post-deployment script supports SQL Managed Instance only. Selected database type: '$($secondaryOutputs.databaseType)'."
}

$sqlMiDeployment = $null
$managedInstanceName = [string]$secondaryOutputs.managedInstanceName
$databaseFqdn = [string]$secondaryOutputs.databaseFqdn
$sqlMiPublicEndpoint = [string]$secondaryOutputs.sqlMiPublicEndpoint
$databaseName = [string]$secondaryOutputs.databaseName
if (
    [string]::IsNullOrWhiteSpace($managedInstanceName) -or
    [string]::IsNullOrWhiteSpace($databaseFqdn) -or
    [string]::IsNullOrWhiteSpace($sqlMiPublicEndpoint) -or
    [string]::IsNullOrWhiteSpace($databaseName)
) {
    $sqlMiDeployment = Get-ResourceGroupDeployment `
        -Role SqlMi `
        -ResourceGroup $SecondaryResourceGroup `
        -RequiredOutputs $deploymentOutputContracts.SqlMi `
        -DeploymentName $SqlMiDeploymentName
    $sqlMiOutputs = ConvertFrom-DeploymentOutputs `
        -Outputs $sqlMiDeployment.properties.outputs
    $managedInstanceName = [string]$sqlMiOutputs.managedInstanceName
    $databaseFqdn = [string]$sqlMiOutputs.managedInstanceFqdn
    $sqlMiPublicEndpoint = [string]$sqlMiOutputs.managedInstancePublicEndpoint
    $databaseName = [string]$sqlMiOutputs.managedDatabaseName
}
if ($databaseName -cne 'eshop_ai') {
    throw "Expected database name 'eshop_ai', but the selected deployment returned '$databaseName'."
}

$selectedDeployments = [ordered]@{
    Bootstrap = $bootstrapDeployment
    Secondary = $secondaryDeployment
    Global = $globalDeployment
}
if ($null -ne $sqlMiDeployment) {
    $selectedDeployments.SqlMi = $sqlMiDeployment
}
Assert-DeploymentBoundary -Deployments $selectedDeployments

$values = [ordered]@{
    LAB04_BOOTSTRAP_RESOURCE_GROUP = $BootstrapResourceGroup
    LAB04_SECONDARY_RESOURCE_GROUP = $SecondaryResourceGroup
    LAB04_GLOBAL_RESOURCE_GROUP = $GlobalResourceGroup
    LAB04_DATABASE_MODE = 'sqlMi'
    LAB04_DATABASE_NAME = $databaseName
    LAB04_DATABASE_SERVER_NAME = $managedInstanceName
    LAB04_DATABASE_FQDN = $databaseFqdn
    LAB04_SQL_MI_PUBLIC_ENDPOINT = $sqlMiPublicEndpoint
    LAB04_SQL_MI_NSG_NAME = [string]$secondaryOutputs.sqlMiNetworkSecurityGroupName
    LAB05_RETAIL_DATABASE_NAME = [string]$secondaryOutputs.retailDatabaseName
    LAB06_CONTAINER_APP_NAME = [string]$secondaryOutputs.containerAppName
    LAB06_RUNTIME_IDENTITY_CLIENT_ID = [string]$bootstrapOutputs.runtimeIdentityClientId
    LAB04_CONTAINER_APPS_ENVIRONMENT_ID = [string]$secondaryOutputs.containerAppsEnvironmentId
    FRONT_DOOR_ENDPOINT = [string]$globalOutputs.frontDoorEndpointHostName
    FRONT_DOOR_ORIGIN_ID = [string]$globalOutputs.frontDoorOriginId
    FRONT_DOOR_PRIVATE_LINK_REQUEST_MESSAGE = [string]$globalOutputs.privateLinkRequestMessage
}
$missingValues = @(
    $values.GetEnumerator() |
        Where-Object { [string]::IsNullOrWhiteSpace("$($_.Value)") } |
        ForEach-Object Key
)
if ($missingValues.Count -gt 0) {
    throw "Post-deployment discovery is missing required values: $($missingValues -join ', ')."
}

$discovery = [ordered]@{
    SubscriptionId = $SubscriptionId
    ResourceGroups = [ordered]@{
        Bootstrap = $BootstrapResourceGroup
        Secondary = $SecondaryResourceGroup
        Global = $GlobalResourceGroup
    }
    Deployments = [ordered]@{
        Bootstrap = $bootstrapDeployment.name
        Secondary = $secondaryDeployment.name
        Global = $globalDeployment.name
        SqlMi = if ($null -ne $sqlMiDeployment) {
            $sqlMiDeployment.name
        }
        else {
            $secondaryDeployment.name
        }
    }
    Values = $values
}
if ($DiscoveryOnly -or $WhatIfPreference) {
    $discovery | ConvertTo-Json -Depth 5
    if ($WhatIfPreference) {
        Write-Host 'WhatIf: would approve Front Door Private Link, verify Front Door health, import or preserve eshop_ai, and configure the Container App database settings.'
    }
    return
}

Approve-FrontDoorPrivateLink `
    -EnvironmentId $values.LAB04_CONTAINER_APPS_ENVIRONMENT_ID `
    -OriginId $values.FRONT_DOOR_ORIGIN_ID `
    -RequestMessage $values.FRONT_DOOR_PRIVATE_LINK_REQUEST_MESSAGE `
    -EndpointHostName $values.FRONT_DOOR_ENDPOINT

$existingDatabaseCount = az sql midb list `
    --subscription $SubscriptionId `
    --resource-group $SecondaryResourceGroup `
    --managed-instance $managedInstanceName `
    --query "[?name=='$databaseName'] | length(@)" `
    --output tsv
$databaseImported = $false
if ([int]$existingDatabaseCount -gt 0 -and -not $ReplaceExistingDatabase) {
    Write-Host "Database '$databaseName' already exists on '$managedInstanceName'; preserving it and skipping BACPAC import."
}
else {
    if ([int]$existingDatabaseCount -gt 0) {
        $deleteApproved = $PSCmdlet.ShouldProcess(
            "$SecondaryResourceGroup/$managedInstanceName/$databaseName",
            'Delete existing SQL Managed Instance database'
        )
        if (-not $deleteApproved) {
            throw "Database replacement was requested but deletion of '$databaseName' was not approved."
        }
        if ($deleteApproved) {
            az sql midb delete `
                --subscription $SubscriptionId `
                --resource-group $SecondaryResourceGroup `
                --managed-instance $managedInstanceName `
                --name $databaseName `
                --yes `
                --output none
        }
        $databaseDeleted = $false
        for ($attempt = 1; $attempt -le 40; $attempt++) {
            $remaining = az sql midb list `
                --subscription $SubscriptionId `
                --resource-group $SecondaryResourceGroup `
                --managed-instance $managedInstanceName `
                --query "[?name=='$databaseName'] | length(@)" `
                --output tsv
            if ([int]$remaining -eq 0) {
                $databaseDeleted = $true
                break
            }
            Start-Sleep -Seconds 15
        }
        if (-not $databaseDeleted) {
            throw "Database '$databaseName' was not deleted within ten minutes."
        }
        Start-Sleep -Seconds 30
    }

    $BacpacPath = Resolve-StandaloneBacpacPath -OverridePath $BacpacPath
    $sqlPackagePath = Resolve-Lab04SqlPackage -ProjectRoot $toolCacheRoot
    $publicIpAddress = (
        Invoke-RestMethod -Uri 'https://api.ipify.org' -Method Get -TimeoutSec 15
    ).ToString().Trim()
    if (-not (Test-Lab04PublicIPv4Address -IpAddress $publicIpAddress)) {
        throw "api.ipify.org returned invalid public IPv4 address '$publicIpAddress'."
    }

    $ruleName = New-Lab04DatabaseImportRuleName `
        -SubscriptionId $SubscriptionId `
        -EnvironmentName $SecondaryResourceGroup `
        -DatabaseMode sqlMi
    $ruleCreated = $false
    $operationError = $null
    $cleanupFailures = [System.Collections.Generic.List[string]]::new()
    try {
        az network nsg rule create `
            --subscription $SubscriptionId `
            --resource-group $SecondaryResourceGroup `
            --nsg-name $values.LAB04_SQL_MI_NSG_NAME `
            --name $ruleName `
            --priority 1200 `
            --access Allow `
            --direction Inbound `
            --protocol Tcp `
            --source-address-prefixes "$publicIpAddress/32" `
            --source-port-ranges '*' `
            --destination-address-prefixes '*' `
            --destination-port-ranges 3342 `
            --description 'Temporary BACPAC import access; removed by post-deployment automation.' `
            --output none
        $ruleCreated = $true

        $accessToken = az account get-access-token `
            --subscription $SubscriptionId `
            --resource 'https://database.windows.net/' `
            --query accessToken `
            --output tsv
        if ([string]::IsNullOrWhiteSpace($accessToken)) {
            throw 'Azure CLI did not return an Azure SQL access token.'
        }
        $sqlPackageArguments = @(
            '/Action:Import'
            "/SourceFile:$BacpacPath"
            "/TargetServerName:$sqlMiPublicEndpoint"
            "/TargetDatabaseName:$databaseName"
            "/AccessToken:$accessToken"
            '/TargetEncryptConnection:True'
            '/TargetTrustServerCertificate:False'
            '/TargetTimeout:60'
        )
        & $sqlPackagePath @sqlPackageArguments
        if ($LASTEXITCODE -ne 0) {
            throw "SqlPackage import failed with exit code $LASTEXITCODE."
        }
        $databaseImported = $true
    }
    catch {
        $operationError = $_
    }
    finally {
        $accessToken = $null
        if ($ruleCreated) {
            try {
                az network nsg rule delete `
                    --subscription $SubscriptionId `
                    --resource-group $SecondaryResourceGroup `
                    --nsg-name $values.LAB04_SQL_MI_NSG_NAME `
                    --name $ruleName `
                    --output none
            }
            catch {
                Add-CleanupFailure `
                    -Failures $cleanupFailures `
                    -Action "Removing SQL MI NSG rule '$ruleName'" `
                    -ErrorRecord $_
            }
        }
    }
    if ($operationError) {
        $message = "BACPAC import failed: $($operationError.Exception.Message)"
        if ($cleanupFailures.Count -gt 0) {
            $message += " Cleanup also failed: $($cleanupFailures -join '; ')"
        }
        throw $message
    }
    if ($cleanupFailures.Count -gt 0) {
        throw "BACPAC import completed, but temporary access cleanup failed: $($cleanupFailures -join '; ')"
    }
}

Set-ContainerAppDatabaseConfiguration `
    -ResourceGroup $SecondaryResourceGroup `
    -ContainerAppName $values.LAB06_CONTAINER_APP_NAME `
    -DatabaseFqdn $databaseFqdn `
    -RetailDatabaseName $values.LAB05_RETAIL_DATABASE_NAME `
    -RuntimeIdentityClientId $values.LAB06_RUNTIME_IDENTITY_CLIENT_ID

if ($databaseImported) {
    Write-Host "Imported '$BacpacPath' as database '$databaseName' on '$managedInstanceName'."
}
Write-Host 'Lab 04 post-deployment automation completed.'
