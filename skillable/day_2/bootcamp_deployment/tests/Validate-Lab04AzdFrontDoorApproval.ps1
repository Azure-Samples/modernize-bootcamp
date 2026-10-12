[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$postprovisionPath = Join-Path $projectRoot 'infra\hooks\postprovision.ps1'
$postprovision = Get-Content -LiteralPath $postprovisionPath -Raw

$tokens = $null
$parseErrors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput(
    $postprovision,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "AZD post-provision hook failed parsing: $($parseErrors.Message -join '; ')"
}

foreach ($functionName in @(
    'Get-RequiredAzdValue',
    'Get-HttpStatusSummary',
    'Approve-FrontDoorPrivateLink'
)) {
    $functionAst = $ast.Find(
        {
            param($candidate)

            $candidate -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $candidate.Name -eq $functionName
        },
        $true
    )
    if ($null -eq $functionAst) {
        throw "AZD post-provision hook is missing function '$functionName'."
    }
    Invoke-Expression $functionAst.Extent.Text
}

$mockAzdValues = [pscustomobject]@{
    FRONT_DOOR_ENDPOINT = 'frontdoor.example.com'
}
if (
    (Get-RequiredAzdValue `
        -Values $mockAzdValues `
        -Name 'FRONT_DOOR_ENDPOINT') -ne 'frontdoor.example.com'
) {
    throw 'Required AZD output lookup did not return the expected value.'
}
try {
    Get-RequiredAzdValue `
        -Values $mockAzdValues `
        -Name 'FRONT_DOOR_ORIGIN_ID'
    throw 'Missing required AZD output was accepted.'
}
catch {
    if ($_.Exception.Message -notmatch 'FRONT_DOOR_ORIGIN_ID') {
        throw
    }
}

$script:connections = @()
$script:approvalCount = 0

function az {
    $arguments = @($args)
    $global:LASTEXITCODE = 0

    if (
        $arguments[0] -eq 'network' -and
        $arguments[1] -eq 'private-endpoint-connection'
    ) {
        switch ($arguments[2]) {
            'list' {
                return ConvertTo-Json -InputObject @($script:connections) -Depth 10
            }
            'approve' {
                $script:approvalCount++
                return
            }
            'show' {
                return 'Approved'
            }
        }
    }
    if ($arguments[0] -eq 'resource' -and $arguments[1] -eq 'show') {
        return 'origin.example.com'
    }

    throw "Unexpected mocked Azure CLI command: $($arguments -join ' ')"
}

function Invoke-WebRequest {
    param(
        [string]$Uri,
        [string]$Method,
        [int]$TimeoutSec,
        [switch]$UseBasicParsing
    )

    return [pscustomobject]@{
        StatusCode = 200
        ReasonPhrase = 'OK'
    }
}

function Start-Sleep {
    param([int]$Seconds)
}

function New-Connection {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][ValidateSet('Pending', 'Approved')][string]$Status,
        [string]$Id = '/mock/privateEndpointConnections/front-door'
    )

    return [pscustomobject]@{
        id = $Id
        properties = [pscustomobject]@{
            privateLinkServiceConnectionState = [pscustomobject]@{
                description = $Description
                status = $Status
            }
        }
    }
}

$approvalParameters = @{
    EnvironmentId = '/mock/managedEnvironments/lab04'
    OriginId = '/mock/frontDoors/origins/application'
    RequestMessage = 'expected-front-door-request'
    EndpointHostName = 'frontdoor.example.com'
    ConnectionAttemptLimit = 1
    ConnectionDelaySeconds = 0
    EndpointAttemptLimit = 1
    EndpointDelaySeconds = 0
}

$script:connections = @(
    New-Connection `
        -Description $approvalParameters.RequestMessage `
        -Status Pending
)
$script:approvalCount = 0
Approve-FrontDoorPrivateLink @approvalParameters
if ($script:approvalCount -ne 1) {
    throw 'A matching pending Front Door connection was not approved exactly once.'
}

$script:connections = @(
    New-Connection `
        -Description $approvalParameters.RequestMessage `
        -Status Approved
)
$script:approvalCount = 0
Approve-FrontDoorPrivateLink @approvalParameters
if ($script:approvalCount -ne 0) {
    throw 'An already-approved Front Door connection was approved again.'
}

$script:connections = @(
    New-Connection -Description 'unknown-request' -Status Pending
)
$script:approvalCount = 0
try {
    Approve-FrontDoorPrivateLink @approvalParameters
    throw 'An unknown pending connection was accepted.'
}
catch {
    if (
        $_.Exception.Message -notmatch
            'Unknown pending private endpoint connection'
    ) {
        throw
    }
}
if ($script:approvalCount -ne 0) {
    throw 'An unknown pending connection was approved.'
}

$script:connections = @(
    New-Connection `
        -Description $approvalParameters.RequestMessage `
        -Status Pending `
        -Id '/mock/privateEndpointConnections/one'
    New-Connection `
        -Description $approvalParameters.RequestMessage `
        -Status Pending `
        -Id '/mock/privateEndpointConnections/two'
)
$script:approvalCount = 0
try {
    Approve-FrontDoorPrivateLink @approvalParameters
    throw 'Duplicate matching Front Door connections were accepted.'
}
catch {
    if (
        $_.Exception.Message -notmatch
            'Multiple private endpoint connections'
    ) {
        throw
    }
}
if ($script:approvalCount -ne 0) {
    throw 'A duplicate matching Front Door connection was approved.'
}

Write-Host 'Lab 04 AZD Front Door approval scenarios are valid.'
