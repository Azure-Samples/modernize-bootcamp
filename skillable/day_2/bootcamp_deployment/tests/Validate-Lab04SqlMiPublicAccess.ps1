[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $projectRoot 'assets\scripts\Lab04SqlMiPublicAccess.ps1'
$scriptPaths = @(
    (Join-Path $projectRoot 'assets\scripts\Enable-Lab04SqlMiPublicAccess.ps1'),
    (Join-Path $projectRoot '..\..\..\assets\scripts\Enable-Lab04SqlMiPublicAccess.ps1')
)
. $helperPath

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

$parameters = @{
    SubscriptionId = '11111111-1111-1111-1111-111111111111'
    TenantId = '22222222-2222-2222-2222-222222222222'
    AccountName = 'participant@example.com'
}
$ruleName = New-Lab04SqlMiParticipantRuleName @parameters
$repeatedRuleName = New-Lab04SqlMiParticipantRuleName @parameters
$normalizedRuleName = New-Lab04SqlMiParticipantRuleName `
    -SubscriptionId " $($parameters.SubscriptionId.ToUpperInvariant()) " `
    -TenantId $parameters.TenantId.ToUpperInvariant() `
    -AccountName $parameters.AccountName.ToUpperInvariant()
$otherSubscriptionRuleName = New-Lab04SqlMiParticipantRuleName `
    -SubscriptionId '33333333-3333-3333-3333-333333333333' `
    -TenantId $parameters.TenantId `
    -AccountName $parameters.AccountName
$otherParticipantRuleName = New-Lab04SqlMiParticipantRuleName `
    -SubscriptionId $parameters.SubscriptionId `
    -TenantId $parameters.TenantId `
    -AccountName 'another-participant@example.com'

foreach ($response in @('y', 'Y', 'yes', 'YES', 'YeS', ' yes ')) {
    Assert-Contract (Test-Lab04AffirmativeResponse -Response $response) `
        "The consent response '$response' must be accepted."
}
foreach ($response in @('', 'n', 'no', 'yeah', 'yesterday')) {
    Assert-Contract (-not (Test-Lab04AffirmativeResponse -Response $response)) `
        "The consent response '$response' must be rejected."
}

Assert-Contract ($ruleName -eq 'AllowSqlMi-9207e5e246c15b5171f3c6e876f70020') `
    'Known account metadata must produce the expected SHA-256-based rule name.'
Assert-Contract ($ruleName -eq $repeatedRuleName) `
    'Identical account metadata must produce a stable rule name.'
Assert-Contract ($ruleName -eq $normalizedRuleName) `
    'Rule name inputs must be normalized for case and surrounding whitespace.'
Assert-Contract ($ruleName -ne $otherSubscriptionRuleName) `
    'Different subscriptions must produce different rule names.'
Assert-Contract ($ruleName -ne $otherParticipantRuleName) `
    'Different participant accounts must produce different rule names.'
Assert-Contract ($ruleName -match '^AllowSqlMi-[0-9a-f]{32}$') `
    'The generated rule name must use the expected bounded, NSG-safe format.'
Assert-Contract ($ruleName -notlike "*$($parameters.AccountName)*") `
    'The generated rule name must not expose the participant account name.'

Assert-ThrowsLike `
    -Action {
        New-Lab04SqlMiParticipantRuleName `
            -SubscriptionId $parameters.SubscriptionId `
            -TenantId $parameters.TenantId `
            -AccountName ' '
    } `
    -Pattern '*account metadata are required*' `
    -Message 'Missing account metadata must produce an actionable error.'

foreach ($scriptPath in $scriptPaths) {
    $scriptContent = Get-Content -LiteralPath $scriptPath -Raw
    Assert-Contract ($scriptContent -notmatch 'az\s+ad\s+signed-in-user') `
        "$scriptPath must not require Microsoft Graph to generate a rule name."
    Assert-Contract ($scriptContent -match 'if\s*\(-not\s+\$RuleName\)') `
        "$scriptPath must preserve the explicit RuleName override."
    Assert-Contract ($scriptContent -match 'New-Lab04SqlMiParticipantRuleName') `
        "$scriptPath must use the validated participant rule-name helper."
    Assert-Contract ($scriptContent -match 'Test-Lab04AffirmativeResponse') `
        "$scriptPath must accept validated case-insensitive consent responses."
}

if ($failures.Count -gt 0) {
    throw "Lab 04 SQL MI public access validation failed:`n- $($failures -join "`n- ")"
}

Write-Host 'Lab 04 SQL MI public access contracts are valid.'
