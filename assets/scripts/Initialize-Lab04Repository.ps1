[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [string]$Repository,

    [ValidatePattern('^[a-z0-9-]{3,18}$')]
    [string]$Prefix = 'caldova-lab04',

    [string]$PrimaryLocation = 'northcentralus',

    [string]$SecondaryLocation = 'centralus',

    [string]$ApplicationLocation = 'centralus',

    [string]$GitHubEnvironment = 'lab04'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'PowerShell 7 or later is required so native Azure CLI and GitHub CLI failures stop the script.'
}

$PSNativeCommandUseErrorActionPreference = $true

foreach ($command in 'az', 'gh') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command '$command' was not found on PATH."
    }
}

az account show --output none
gh auth status

if ([string]::IsNullOrWhiteSpace($Repository)) {
    $Repository = gh repo view --json nameWithOwner --jq '.nameWithOwner'
}

if ($Repository -notmatch '^[^/]+/[^/]+$') {
    throw "Repository must use the 'owner/name' format. Received '$Repository'."
}

$accountSubscriptionId = az account show --query id --output tsv
if ($accountSubscriptionId -ne $SubscriptionId) {
    az account set --subscription $SubscriptionId
}

$tenantId = az account show --query tenantId --output tsv
$participantObjectId = az ad signed-in-user show --query id --output tsv
$participantLogin = az ad signed-in-user show --query userPrincipalName --output tsv
if ([string]::IsNullOrWhiteSpace($participantObjectId)) {
    throw 'Unable to resolve the signed-in participant object ID.'
}
if ([string]::IsNullOrWhiteSpace($participantLogin)) {
    throw 'Unable to resolve the signed-in participant user principal name for the Entra-only SQL administrator.'
}

$hashInput = [Text.Encoding]::UTF8.GetBytes("$SubscriptionId|$Repository|$Prefix")
$hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($hashInput)).ToLowerInvariant()
$suffix = $hash.Substring(0, 6)
$safePrefix = ($Prefix -replace '[^a-z0-9]', '').ToLowerInvariant()
$keyVaultName = "$($safePrefix.Substring(0, [Math]::Min($safePrefix.Length, 14)))$suffix-kv"
$identityName = "$Prefix-deploy-$suffix"
$codeDeploymentIdentityName = "$Prefix-code-deploy-$suffix"
$nameToken = $safePrefix.Substring(0, [Math]::Min($safePrefix.Length, 12))
$containerRegistryName = "${nameToken}cr${suffix}"
$containerAppName = "$nameToken-application-$suffix-app"

$resourceGroups = [ordered]@{
    Bootstrap = "rg-$Prefix-bootstrap-$suffix"
    Primary   = "rg-$Prefix-primary-$suffix"
    Secondary = "rg-$Prefix-secondary-$suffix"
    Global    = "rg-$Prefix-global-$suffix"
}

function Add-RoleAssignmentIfMissing {
    param(
        [Parameter(Mandatory)]
        [string]$PrincipalId,

        [Parameter(Mandatory)]
        [ValidateSet('User', 'ServicePrincipal', 'Group')]
        [string]$PrincipalType,

        [Parameter(Mandatory)]
        [string]$Role,

        [Parameter(Mandatory)]
        [string]$Scope
    )

    $existingCount = az role assignment list `
        --scope $Scope `
        --query "[?principalId=='$PrincipalId' && roleDefinitionName=='$Role'] | length(@)" `
        --output tsv

    if ([int]$existingCount -eq 0) {
        az role assignment create `
            --assignee-object-id $PrincipalId `
            --assignee-principal-type $PrincipalType `
            --role $Role `
            --scope $Scope `
            --output none
    }
}

function Get-OrCreateUserAssignedIdentity {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$Location
    )

    $identity = az identity list `
        --resource-group $ResourceGroupName `
        --query "[?name=='$Name'] | [0]" `
        --output json | ConvertFrom-Json

    if ($null -eq $identity) {
        $identity = az identity create `
            --name $Name `
            --resource-group $ResourceGroupName `
            --location $Location `
            --output json | ConvertFrom-Json
    }

    return $identity
}

function Set-GitHubFederatedCredential {
    param(
        [Parameter(Mandatory)]
        [string]$IdentityName,

        [Parameter(Mandatory)]
        [string]$ResourceGroupName,

        [Parameter(Mandatory)]
        [string]$EnvironmentName
    )

    $credentialName = "github-$EnvironmentName"
    $subject = "repo:$Repository`:environment:$EnvironmentName"
    $credential = az identity federated-credential list `
        --identity-name $IdentityName `
        --resource-group $ResourceGroupName `
        --query "[?name=='$credentialName'] | [0]" `
        --output json | ConvertFrom-Json

    if ($null -eq $credential) {
        az identity federated-credential create `
            --name $credentialName `
            --identity-name $IdentityName `
            --resource-group $ResourceGroupName `
            --issuer 'https://token.actions.githubusercontent.com' `
            --subject $subject `
            --audiences 'api://AzureADTokenExchange' `
            --output none
    }
    else {
        az identity federated-credential update `
            --name $credentialName `
            --identity-name $IdentityName `
            --resource-group $ResourceGroupName `
            --issuer 'https://token.actions.githubusercontent.com' `
            --subject $subject `
            --audiences 'api://AzureADTokenExchange' `
            --output none
    }
}

Write-Host 'Registering the Azure resource providers used by the lab.'
foreach ($provider in @(
        'Microsoft.App',
        'Microsoft.Cdn',
        'Microsoft.Compute',
        'Microsoft.ContainerRegistry',
        'Microsoft.DataMigration',
        'Microsoft.Insights',
        'Microsoft.KeyVault',
        'Microsoft.ManagedIdentity',
        'Microsoft.Network',
        'Microsoft.OperationalInsights',
        'Microsoft.Sql'
    )) {
    az provider register --namespace $provider --wait
}

Write-Host 'Creating narrowly scoped resource groups.'
az group create --name $resourceGroups.Bootstrap --location $PrimaryLocation --tags `
    Application=Caldova Environment=Lab Owner=$participantObjectId CostCenter=Bootcamp ManagedBy=Bootstrap --output none
az group create --name $resourceGroups.Primary --location $PrimaryLocation --tags `
    Application=Caldova Environment=Lab Owner=$participantObjectId CostCenter=Bootcamp ManagedBy=Bicep --output none
az group create --name $resourceGroups.Secondary --location $SecondaryLocation --tags `
    Application=Caldova Environment=Lab Owner=$participantObjectId CostCenter=Bootcamp ManagedBy=Bicep --output none
az group create --name $resourceGroups.Global --location $PrimaryLocation --tags `
    Application=Caldova Environment=Lab Owner=$participantObjectId CostCenter=Bootcamp ManagedBy=Bicep --output none

Write-Host 'Creating the RBAC-enabled bootstrap Key Vault and deployment identities.'
az keyvault create `
    --name $keyVaultName `
    --resource-group $resourceGroups.Bootstrap `
    --location $PrimaryLocation `
    --enable-rbac-authorization true `
    --public-network-access Enabled `
    --output none

$identity = Get-OrCreateUserAssignedIdentity `
    -Name $identityName `
    -ResourceGroupName $resourceGroups.Bootstrap `
    -Location $PrimaryLocation

$codeDeploymentIdentity = Get-OrCreateUserAssignedIdentity `
    -Name $codeDeploymentIdentityName `
    -ResourceGroupName $resourceGroups.Bootstrap `
    -Location $ApplicationLocation

$subscriptionScope = "/subscriptions/$SubscriptionId"
$keyVaultScope = "$subscriptionScope/resourceGroups/$($resourceGroups.Bootstrap)/providers/Microsoft.KeyVault/vaults/$keyVaultName"

Add-RoleAssignmentIfMissing `
    -PrincipalId $participantObjectId `
    -PrincipalType User `
    -Role 'Key Vault Secrets Officer' `
    -Scope $keyVaultScope

Add-RoleAssignmentIfMissing `
    -PrincipalId $identity.principalId `
    -PrincipalType ServicePrincipal `
    -Role 'Key Vault Secrets User' `
    -Scope $keyVaultScope

foreach ($resourceGroupName in @($resourceGroups.Primary, $resourceGroups.Secondary, $resourceGroups.Global)) {
    $scope = "$subscriptionScope/resourceGroups/$resourceGroupName"
    Add-RoleAssignmentIfMissing `
        -PrincipalId $identity.principalId `
        -PrincipalType ServicePrincipal `
        -Role Contributor `
        -Scope $scope

    # Bicep creates only resource-scoped workload role assignments. Keep the
    # infrastructure identity's assignment permission below subscription scope.
    Add-RoleAssignmentIfMissing `
        -PrincipalId $identity.principalId `
        -PrincipalType ServicePrincipal `
        -Role 'Role Based Access Control Administrator' `
        -Scope $scope
}

$deploymentEnvironment = "$GitHubEnvironment-deploy"
foreach ($environmentName in @($GitHubEnvironment, $deploymentEnvironment)) {
    Set-GitHubFederatedCredential `
        -IdentityName $identityName `
        -ResourceGroupName $resourceGroups.Bootstrap `
        -EnvironmentName $environmentName
}

$codeDeploymentEnvironments = @('lab06', 'lab06-deploy')
foreach ($environmentName in $codeDeploymentEnvironments) {
    Set-GitHubFederatedCredential `
        -IdentityName $codeDeploymentIdentityName `
        -ResourceGroupName $resourceGroups.Bootstrap `
        -EnvironmentName $environmentName
}

$alphabet = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@$%*-_=+'
$randomBytes = [byte[]]::new(32)
[Security.Cryptography.RandomNumberGenerator]::Fill($randomBytes)
$vmAdminPassword = -join ($randomBytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })
$vmAdminUsername = 'labadmin'

Write-Host 'Storing generated VM credentials in Key Vault. Values are intentionally not displayed.'
$stored = $false
for ($attempt = 1; $attempt -le 12 -and -not $stored; $attempt++) {
    try {
        az keyvault secret set --vault-name $keyVaultName --name vm-admin-username --value $vmAdminUsername --output none
        az keyvault secret set --vault-name $keyVaultName --name vm-admin-password --value $vmAdminPassword --output none
        $stored = $true
    }
    catch {
        if ($attempt -eq 12) {
            throw 'Key Vault RBAC propagation did not complete in time; credentials were not stored.'
        }
        Start-Sleep -Seconds 10
    }
}
$vmAdminPassword = $null
$randomBytes = $null

Write-Host 'Configuring GitHub infrastructure and code-deployment environments and their non-secret variables.'
foreach ($environmentName in @($GitHubEnvironment, $deploymentEnvironment)) {
    gh api --method PUT "repos/$Repository/environments/$environmentName" --silent
}
foreach ($environmentName in $codeDeploymentEnvironments) {
    gh api --method PUT "repos/$Repository/environments/$environmentName" --silent
}

$variables = [ordered]@{
    AZURE_CLIENT_ID              = $identity.clientId
    AZURE_TENANT_ID              = $tenantId
    AZURE_SUBSCRIPTION_ID        = $SubscriptionId
    LAB04_BOOTSTRAP_RESOURCE_GROUP = $resourceGroups.Bootstrap
    LAB04_PRIMARY_RESOURCE_GROUP = $resourceGroups.Primary
    LAB04_SECONDARY_RESOURCE_GROUP = $resourceGroups.Secondary
    LAB04_GLOBAL_RESOURCE_GROUP  = $resourceGroups.Global
    LAB04_KEY_VAULT_NAME         = $keyVaultName
    LAB04_DEPLOYMENT_IDENTITY_NAME = $identityName
    LAB06_AZURE_CLIENT_ID         = $codeDeploymentIdentity.clientId
    LAB06_AZURE_PRINCIPAL_ID      = $codeDeploymentIdentity.principalId
    LAB06_DEPLOYMENT_IDENTITY_NAME = $codeDeploymentIdentityName
    LAB04_PREFIX                 = $Prefix
    LAB04_PRIMARY_LOCATION       = $PrimaryLocation
    LAB04_SECONDARY_LOCATION     = $SecondaryLocation
    LAB04_APPLICATION_LOCATION   = $ApplicationLocation
    LAB04_SQL_ADMIN_OBJECT_ID    = $participantObjectId
    LAB04_SQL_ADMIN_LOGIN        = $participantLogin
    LAB04_SUFFIX                 = $suffix
}

foreach ($entry in $variables.GetEnumerator()) {
    foreach ($environmentName in @($GitHubEnvironment, $deploymentEnvironment)) {
        gh variable set $entry.Key --env $environmentName --repo $Repository --body $entry.Value
    }
}

$codeDeploymentVariables = [ordered]@{
    AZURE_CLIENT_ID                 = $codeDeploymentIdentity.clientId
    AZURE_TENANT_ID                 = $tenantId
    AZURE_SUBSCRIPTION_ID           = $SubscriptionId
    LAB06_AZURE_CLIENT_ID           = $codeDeploymentIdentity.clientId
    LAB06_AZURE_PRINCIPAL_ID        = $codeDeploymentIdentity.principalId
    LAB06_DEPLOYMENT_IDENTITY_NAME  = $codeDeploymentIdentityName
    LAB06_CONTAINER_REGISTRY_NAME   = $containerRegistryName
    LAB06_CONTAINER_APP_NAME        = $containerAppName
    LAB04_PRIMARY_RESOURCE_GROUP    = $resourceGroups.Primary
    LAB04_SECONDARY_RESOURCE_GROUP  = $resourceGroups.Secondary
    LAB04_GLOBAL_RESOURCE_GROUP     = $resourceGroups.Global
    LAB04_APPLICATION_LOCATION      = $ApplicationLocation
    LAB04_PREFIX                    = $Prefix
    LAB04_SUFFIX                    = $suffix
}

foreach ($entry in $codeDeploymentVariables.GetEnumerator()) {
    foreach ($environmentName in $codeDeploymentEnvironments) {
        gh variable set $entry.Key --env $environmentName --repo $Repository --body $entry.Value
    }
}

Write-Host ''
Write-Host 'Lab 04 repository bootstrap completed.'
Write-Host "Repository: $Repository"
Write-Host "GitHub plan environment: $GitHubEnvironment"
Write-Host "GitHub protected deployment environment: $deploymentEnvironment"
Write-Host 'GitHub code environments: lab06, lab06-deploy'
Write-Host "Bootstrap resource group: $($resourceGroups.Bootstrap)"
Write-Host "Key Vault: $keyVaultName"
Write-Host "Code deployment identity: $codeDeploymentIdentityName"
Write-Host 'Retrieve VM credentials only when needed with Key Vault RBAC; do not copy them into repository files.'
