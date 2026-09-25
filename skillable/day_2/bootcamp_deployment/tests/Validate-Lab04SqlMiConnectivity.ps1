[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $projectRoot 'assets\scripts\Lab04SqlMiConnectivity.ps1')

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

function Assert-ThrowsLike {
    param(
        [Parameter(Mandatory)][scriptblock]$Action,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$Message
    )

    try {
        & $Action
        $failures.Add("$Message No exception was thrown.")
    }
    catch {
        if ($_.Exception.Message -notlike $Pattern) {
            $failures.Add("$Message Received: $($_.Exception.Message)")
        }
    }
}

$endpoint = ConvertTo-Lab04SqlMiPublicEndpoint `
    -Endpoint 'example.public.0123456789.database.windows.net,3342'
Assert-Contract ($endpoint.HostName -eq 'example.public.0123456789.database.windows.net') `
    'The SQL MI public endpoint hostname was not parsed correctly.'
Assert-Contract ($endpoint.Port -eq 3342) `
    'The SQL MI public endpoint port was not parsed correctly.'

Assert-ThrowsLike `
    -Action { ConvertTo-Lab04SqlMiPublicEndpoint -Endpoint 'example.database.windows.net' } `
    -Pattern "*format '<hostname>,3342'*" `
    -Message 'An endpoint without a port must be rejected.'
Assert-ThrowsLike `
    -Action { ConvertTo-Lab04SqlMiPublicEndpoint -Endpoint 'example.database.windows.net,1433' } `
    -Pattern '*TCP port 3342*' `
    -Message 'An endpoint using a port other than 3342 must be rejected.'
Assert-ThrowsLike `
    -Action { ConvertTo-Lab04SqlMiPublicEndpoint -Endpoint 'not a hostname,3342' } `
    -Pattern '*valid DNS hostname*' `
    -Message 'An endpoint with an invalid hostname must be rejected.'

$listener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
try {
    $listener.Start()
    $listenerPort = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
    Wait-Lab04SqlMiPublicEndpoint `
        -HostName 'localhost' `
        -Port $listenerPort `
        -RetryCount 1 `
        -RetryDelaySeconds 0 `
        -ConnectionTimeoutSeconds 1
}
catch {
    $failures.Add("A listening TCP endpoint should be reachable. Received: $($_.Exception.Message)")
}
finally {
    $listener.Stop()
}

$closedPortListener = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0)
$closedPortListener.Start()
$closedPort = ([Net.IPEndPoint]$closedPortListener.LocalEndpoint).Port
$closedPortListener.Stop()

Assert-ThrowsLike `
    -Action {
        Wait-Lab04SqlMiPublicEndpoint `
            -HostName 'localhost' `
            -Port $closedPort `
            -RetryCount 2 `
            -RetryDelaySeconds 0 `
            -ConnectionTimeoutSeconds 1
    } `
    -Pattern "*was not reachable after 2 attempt(s).*TCP connection *" `
    -Message 'Retry exhaustion must report an actionable TCP failure.'

Assert-ThrowsLike `
    -Action {
        Wait-Lab04SqlMiPublicEndpoint `
            -HostName 'invalid.invalid' `
            -Port 3342 `
            -RetryCount 1 `
            -RetryDelaySeconds 0 `
            -ConnectionTimeoutSeconds 1
    } `
    -Pattern "*was not reachable after 1 attempt(s).*DNS resolution failed:*" `
    -Message 'DNS failure must be distinguished from TCP failure.'

if ($failures.Count -gt 0) {
    throw "Lab 04 SQL MI connectivity validation failed:`n- $($failures -join "`n- ")"
}

Write-Host 'Lab 04 SQL MI connectivity contracts are valid.'
