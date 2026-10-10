[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Get-RequiredAzdValue {
    param(
        [Parameter(Mandatory)][object]$Values,
        [Parameter(Mandatory)][string]$Name
    )

    $property = $Values.PSObject.Properties[$Name]
    $value = if ($property) {
        $property.Value
    }
    else {
        $null
    }
    if ([string]::IsNullOrWhiteSpace("$value")) {
        throw "The active AZD environment did not return '$Name'."
    }

    return [string]$value
}

function Get-HttpStatusSummary {
    param([Parameter(Mandatory)][object]$Response)

    $description = $null
    foreach ($propertyName in @('StatusDescription', 'ReasonPhrase')) {
        $property = $Response.PSObject.Properties[$propertyName]
        if ($property -and -not [string]::IsNullOrWhiteSpace("$($property.Value)")) {
            $description = [string]$property.Value
            break
        }
    }

    $summary = "HTTP $([int]$Response.StatusCode)"
    if ($description) {
        $summary += " $description"
    }

    return $summary
}

function Approve-FrontDoorPrivateLink {
    param(
        [Parameter(Mandatory)][string]$EnvironmentId,
        [Parameter(Mandatory)][string]$OriginId,
        [Parameter(Mandatory)][string]$RequestMessage,
        [Parameter(Mandatory)][string]$EndpointHostName,
        [ValidateRange(1, 100)][int]$ConnectionAttemptLimit = 20,
        [ValidateRange(0, 300)][int]$ConnectionDelaySeconds = 15,
        [ValidateRange(1, 100)][int]$EndpointAttemptLimit = 60,
        [ValidateRange(0, 300)][int]$EndpointDelaySeconds = 30
    )

    $connectionApproved = $false
    for ($attempt = 1; $attempt -le $ConnectionAttemptLimit; $attempt++) {
        $connectionsJson = az network private-endpoint-connection list `
            --id $EnvironmentId `
            --output json
        if ($LASTEXITCODE -ne 0) {
            throw "Unable to list private endpoint connections for '$EnvironmentId'."
        }
        $connections = @($connectionsJson | ConvertFrom-Json)

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
                    --id $connection.id `
                    --description $RequestMessage `
                    --output none
                if ($LASTEXITCODE -ne 0) {
                    throw "Unable to approve Front Door private endpoint connection '$($connection.id)'."
                }
            }

            $connectionStatus = az network private-endpoint-connection show `
                --id $connection.id `
                --query properties.privateLinkServiceConnectionState.status `
                --output tsv
            if ($LASTEXITCODE -ne 0) {
                throw "Unable to verify Front Door private endpoint connection '$($connection.id)'."
            }
            if ("$connectionStatus".Trim() -eq 'Approved') {
                $connectionApproved = $true
                break
            }
        }

        if ($attempt -lt $ConnectionAttemptLimit) {
            Start-Sleep -Seconds $ConnectionDelaySeconds
        }
    }

    if (-not $connectionApproved) {
        throw 'The expected Front Door Private Link request was not approved within five minutes.'
    }

    $originHostName = az resource show `
        --ids $OriginId `
        --api-version 2024-02-01 `
        --query properties.hostName `
        --output tsv
    if (
        $LASTEXITCODE -ne 0 -or
        [string]::IsNullOrWhiteSpace("$originHostName")
    ) {
        throw 'The expected Front Door origin could not be verified.'
    }

    $endpointReady = $false
    $endpointUri = "https://$EndpointHostName/"
    $lastProbeFailure = 'No HTTP response was received.'
    for ($attempt = 1; $attempt -le $EndpointAttemptLimit; $attempt++) {
        try {
            $response = Invoke-WebRequest `
                -Uri $endpointUri `
                -Method Get `
                -TimeoutSec 15 `
                -UseBasicParsing
            if ([int]$response.StatusCode -ge 200 -and [int]$response.StatusCode -lt 400) {
                $endpointReady = $true
                break
            }
            $lastProbeFailure = Get-HttpStatusSummary -Response $response
        }
        catch {
            $webResponse = $_.Exception.Response
            if ($webResponse) {
                $lastProbeFailure = Get-HttpStatusSummary -Response $webResponse
            }
            else {
                $lastProbeFailure = $_.Exception.Message
            }
        }

        if ($attempt -lt $EndpointAttemptLimit) {
            Start-Sleep -Seconds $EndpointDelaySeconds
        }
    }

    if (-not $endpointReady) {
        throw "Front Door endpoint '$endpointUri' did not become healthy within 30 minutes. Last probe: $lastProbeFailure"
    }

    Write-Host "Front Door Private Link is approved and '$endpointUri' is ready."
}

foreach ($command in @('az', 'azd')) {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found on PATH."
    }
}

$azdValuesJson = azd env get-values --output json
if ($LASTEXITCODE -ne 0) {
    throw 'Unable to read the active AZD environment values.'
}
$azdValues = $azdValuesJson | ConvertFrom-Json

$environmentName = Get-RequiredAzdValue `
    -Values $azdValues `
    -Name 'AZURE_ENV_NAME'
$containerAppsEnvironmentId = Get-RequiredAzdValue `
    -Values $azdValues `
    -Name 'LAB04_CONTAINER_APPS_ENVIRONMENT_ID'
$frontDoorOriginId = Get-RequiredAzdValue `
    -Values $azdValues `
    -Name 'FRONT_DOOR_ORIGIN_ID'
$privateLinkRequestMessage = Get-RequiredAzdValue `
    -Values $azdValues `
    -Name 'FRONT_DOOR_PRIVATE_LINK_REQUEST_MESSAGE'
$frontDoorEndpoint = Get-RequiredAzdValue `
    -Values $azdValues `
    -Name 'FRONT_DOOR_ENDPOINT'

Approve-FrontDoorPrivateLink `
    -EnvironmentId $containerAppsEnvironmentId `
    -OriginId $frontDoorOriginId `
    -RequestMessage $privateLinkRequestMessage `
    -EndpointHostName $frontDoorEndpoint

$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$importScriptPath = Join-Path `
    $projectRoot `
    'assets\scripts\Import-Lab04Database.ps1'

& $importScriptPath -AzdEnvironment $environmentName
