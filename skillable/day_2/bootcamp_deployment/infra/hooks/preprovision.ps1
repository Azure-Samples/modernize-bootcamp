[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

function Get-AzdValue {
    param([Parameter(Mandatory)][string]$Name)

    $nativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    try {
        $PSNativeCommandUseErrorActionPreference = $false
        $value = azd env get-value $Name 2>$null
        if ($LASTEXITCODE -ne 0) {
            return $null
        }
    }
    finally {
        $PSNativeCommandUseErrorActionPreference = $nativeErrorPreference
    }

    $trimmed = "$value".Trim()
    return [string]::IsNullOrWhiteSpace($trimmed) ? $null : $trimmed
}

function Set-AzdDefault {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Value
    )

    if (-not (Get-AzdValue -Name $Name)) {
        azd env set $Name $Value
    }
}

foreach ($command in 'az', 'azd') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found on PATH."
    }
}

az account show --output none

Set-AzdDefault -Name LAB04_PREFIX -Value 'caldova-lab04'
Set-AzdDefault -Name LAB04_PRIMARY_LOCATION -Value 'centralus'
Set-AzdDefault -Name LAB04_SECONDARY_LOCATION -Value 'centralus'
Set-AzdDefault -Name LAB04_APPLICATION_LOCATION -Value 'centralus'
Set-AzdDefault -Name LAB04_VM_ADMIN_USERNAME -Value 'labadmin'
Set-AzdDefault -Name LAB04_SQL_MI_PRICING_MODEL -Value 'Freemium'
azd env set AZURE_LOCATION (Get-AzdValue -Name LAB04_PRIMARY_LOCATION)

$prefix = Get-AzdValue -Name LAB04_PREFIX
if ($prefix -notmatch '(?-i)^(?!.*--)[a-z0-9][a-z0-9-]{1,16}[a-z0-9]$') {
    throw 'LAB04_PREFIX must be 3-18 lowercase alphanumeric characters with optional single internal hyphens.'
}

$databaseMode = Get-AzdValue -Name LAB04_DATABASE_MODE
if (-not $databaseMode) {
    $databaseMode = if ([Console]::IsInputRedirected) {
        'sqlMi'
    }
    else {
        $selection = Read-Host 'Database target: 1) Azure SQL Managed Instance (default), 2) Azure SQL Database'
        switch ($selection) {
            { [string]::IsNullOrWhiteSpace($_) } { 'sqlMi'; break }
            '1' { 'sqlMi'; break }
            '2' { 'azureSql'; break }
            default { throw "Invalid database selection '$selection'." }
        }
    }
    azd env set LAB04_DATABASE_MODE $databaseMode
}

if ($databaseMode -notin @('azureSql', 'sqlMi')) {
    throw "LAB04_DATABASE_MODE must be 'azureSql' or 'sqlMi'. Received '$databaseMode'."
}

$environmentName = Get-AzdValue -Name AZURE_ENV_NAME
if ($environmentName) {
    $existingSqlServer = az resource list `
        --tag "azd-env-name=$environmentName" `
        --query "[?type=='Microsoft.Sql/servers'] | [0].id" `
        --output tsv
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect the existing Azure SQL deployment.'
    }
    $existingManagedInstance = az resource list `
        --tag "azd-env-name=$environmentName" `
        --query "[?type=='Microsoft.Sql/managedInstances'] | [0].id" `
        --output tsv
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect the existing SQL Managed Instance deployment.'
    }

    if ($databaseMode -eq 'sqlMi' -and $existingSqlServer) {
        throw "AZD environment '$environmentName' already contains Azure SQL Database. Run 'azd down --purge' and create a new environment to change database modes."
    }
    if ($databaseMode -eq 'azureSql' -and $existingManagedInstance) {
        throw "AZD environment '$environmentName' already contains SQL Managed Instance. Run 'azd down --purge' and create a new environment to change database modes."
    }
}

$sqlMiPricingModel = Get-AzdValue -Name LAB04_SQL_MI_PRICING_MODEL
if ($sqlMiPricingModel -notin @('Freemium', 'Regular')) {
    throw "LAB04_SQL_MI_PRICING_MODEL must be 'Freemium' or 'Regular'. Received '$sqlMiPricingModel'."
}

$sqlAdminLogin = Get-AzdValue -Name LAB04_SQL_ADMIN_LOGIN
$tenantId = az account show --query tenantId --output tsv
if ($sqlAdminLogin) {
    try {
        $sqlAdmin = az ad user show `
            --id $sqlAdminLogin `
            --query '{id:id, login:userPrincipalName}' `
            --output json | ConvertFrom-Json
    }
    catch {
        throw "Unable to resolve SQL administrator '$sqlAdminLogin' as a Microsoft Entra user. Verify the user principal name and reauthenticate with 'az login --tenant $tenantId'."
    }
}
else {
    try {
        $sqlAdmin = az ad signed-in-user show `
            --query '{id:id, login:userPrincipalName}' `
            --output json | ConvertFrom-Json
    }
    catch {
        throw "Unable to resolve the signed-in Microsoft Entra user for SQL administration. Reauthenticate with 'az login --tenant $tenantId', or set LAB04_SQL_ADMIN_LOGIN to a user principal name."
    }
}
if (-not $sqlAdmin.id -or -not $sqlAdmin.login) {
    throw 'The selected Microsoft Entra SQL administrator did not return both an object ID and user principal name.'
}

azd env set LAB04_SQL_ADMIN_OBJECT_ID ([string]$sqlAdmin.id)
azd env set LAB04_SQL_ADMIN_LOGIN ([string]$sqlAdmin.login)

if (-not (Get-AzdValue -Name LAB04_VM_ADMIN_PASSWORD)) {
    $vaultName = $null
    if ($environmentName) {
        $vaults = az keyvault list --output json | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw 'Unable to check for an existing Lab 04 Key Vault.'
        }
        $vaultName = $vaults |
            Where-Object { $_.tags.'azd-env-name' -eq $environmentName } |
            Select-Object -First 1 -ExpandProperty name
    }

    if ($vaultName) {
        $password = az keyvault secret show `
            --vault-name $vaultName `
            --name vm-admin-password `
            --query value `
            --output tsv
        if ($LASTEXITCODE -ne 0 -or -not $password) {
            throw "Unable to recover the existing VM password from Key Vault '$vaultName'."
        }
    }
    else {
        $alphabet = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@$%*-_=+'
        $randomBytes = [byte[]]::new(32)
        [Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
        $password = -join ($randomBytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })
        $randomBytes = $null
    }

    azd env set LAB04_VM_ADMIN_PASSWORD $password
    $password = $null
}

Write-Host "Lab 04 AZD configuration is ready. Database mode: $databaseMode"
