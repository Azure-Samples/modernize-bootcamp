[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$repositoryRoot = Resolve-Path (Join-Path $projectRoot '..\..\..')
$configureScriptPath = Join-Path $projectRoot 'assets\scripts\Configure-Lab04GitHub.ps1'
$deployScriptPath = Join-Path $projectRoot 'infra\Deploy-Lab04.ps1'
$mainBicepPath = Join-Path $projectRoot 'infra\main.bicep'
$parametersPath = Join-Path $projectRoot 'infra\main.parameters.json'
$foundationWorkflowPath = Join-Path $repositoryRoot '.github\workflows\lab04-deploy.yml'
$sqlMiWorkflowPath = Join-Path $repositoryRoot '.github\workflows\lab04-deploy-sqlmi.yml'
$completeBicepPath = Join-Path $projectRoot 'infra\lab04\complete'

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

function Get-ScriptParameterNames {
    param([Parameter(Mandatory)][string]$Path)

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    foreach ($parseError in $parseErrors) {
        $failures.Add("$Path failed PowerShell parsing: $($parseError.Message)")
    }

    return @(
        $ast.ParamBlock.Parameters |
            ForEach-Object { $_.Name.VariablePath.UserPath }
    )
}

function Get-BicepDeclarationNames {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][ValidateSet('param', 'output')][string]$Type
    )

    $content = Get-Content -LiteralPath $Path -Raw
    return @(
        [regex]::Matches($content, "(?m)^\s*$Type\s+([A-Za-z0-9_]+)") |
            ForEach-Object { $_.Groups[1].Value }
    )
}

$configureParameters = Get-ScriptParameterNames -Path $configureScriptPath
$deployParameters = Get-ScriptParameterNames -Path $deployScriptPath

foreach ($name in @(
    'SubscriptionId',
    'AzdEnvironment',
    'DeploymentName',
    'Repository',
    'GitHubEnvironment',
    'RequiredReviewer',
    'DeploymentBranch'
)) {
    Assert-Contract ($name -in $configureParameters) `
        "Configure-Lab04GitHub.ps1 is missing parameter '$name'."
}
foreach ($name in @(
    'SubscriptionId',
    'EnvironmentName',
    'DeploymentName',
    'PrimaryLocation',
    'SecondaryLocation',
    'ApplicationLocation',
    'Prefix',
    'DatabaseMode',
    'SqlMiPricingModel',
    'Action',
    'VmAdminUsername',
    'VmAdminPassword',
    'SqlEntraAdminLogin'
)) {
    Assert-Contract ($name -in $deployParameters) `
        "Deploy-Lab04.ps1 is missing parameter '$name'."
}

$deployScript = Get-Content -LiteralPath $deployScriptPath -Raw
Assert-Contract (
    $deployScript -match '\$armDeploymentName\s*=\s*if\s*\(\$DeploymentName\)'
) 'Deploy-Lab04.ps1 does not honor the optional DeploymentName override.'
Assert-Contract (
    $deployScript -match '"\$EnvironmentName-deploy"'
) 'Deploy-Lab04.ps1 no longer defaults to <EnvironmentName>-deploy.'

$mainParameters = Get-BicepDeclarationNames -Path $mainBicepPath -Type param
$parameterDocument = Get-Content -LiteralPath $parametersPath -Raw |
    ConvertFrom-Json
$mappedParameters = @($parameterDocument.parameters.PSObject.Properties.Name)
foreach ($name in $mainParameters) {
    Assert-Contract ($name -in $mappedParameters) `
        "main.parameters.json does not map main.bicep parameter '$name'."
}
foreach ($name in $mappedParameters) {
    Assert-Contract ($name -in $mainParameters) `
        "main.parameters.json maps unknown main.bicep parameter '$name'."
}

$configureScript = Get-Content -LiteralPath $configureScriptPath -Raw
$requiredValuesMatch = [regex]::Match(
    $configureScript,
    '(?s)\$requiredValues\s*=\s*@\((.*?)\)\s*\r?\n\$missingValues'
)
Assert-Contract $requiredValuesMatch.Success `
    'Could not locate required deployment outputs in Configure-Lab04GitHub.ps1.'
$requiredValues = @(
    [regex]::Matches($requiredValuesMatch.Groups[1].Value, "'([A-Z0-9_]+)'") |
        ForEach-Object { $_.Groups[1].Value }
)
$mainOutputs = Get-BicepDeclarationNames -Path $mainBicepPath -Type output
foreach ($name in $requiredValues | Where-Object { $_ -ne 'AZURE_ENV_NAME' }) {
    Assert-Contract ($name -in $mainOutputs) `
        "Configure-Lab04GitHub.ps1 requires '$name', but main.bicep does not output it."
}

$lab04VariablesMatch = [regex]::Match(
    $configureScript,
    '(?s)\$commonLab04Variables\s*=\s*\[ordered\]@\{(.*?)\r?\n\}'
)
Assert-Contract $lab04VariablesMatch.Success `
    'Could not locate common Lab 04 variables in Configure-Lab04GitHub.ps1.'
$publishedLab04Variables = @(
    [regex]::Matches(
        $lab04VariablesMatch.Groups[1].Value,
        '(?m)^\s*([A-Z][A-Z0-9_]+)\s*='
    ) | ForEach-Object { $_.Groups[1].Value }
) + 'AZURE_CLIENT_ID'

$workflowPaths = @($foundationWorkflowPath, $sqlMiWorkflowPath)
foreach ($workflowPath in $workflowPaths) {
    $workflow = Get-Content -LiteralPath $workflowPath -Raw
    $usedVariables = @(
        [regex]::Matches($workflow, '\$\{\{\s*vars\.([A-Z0-9_]+)\s*\}\}') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
    )
    foreach ($name in $usedVariables) {
        Assert-Contract ($name -in $publishedLab04Variables) `
            "$(Split-Path -Leaf $workflowPath) uses '$name', but OIDC setup does not publish it to Lab 04 environments."
    }
}

$foundationWorkflow = Get-Content -LiteralPath $foundationWorkflowPath -Raw
$primaryParameters = Get-BicepDeclarationNames `
    -Path (Join-Path $completeBicepPath 'primary.bicep') `
    -Type param
$secondaryParameters = Get-BicepDeclarationNames `
    -Path (Join-Path $completeBicepPath 'secondary.bicep') `
    -Type param
$globalParameters = Get-BicepDeclarationNames `
    -Path (Join-Path $completeBicepPath 'global.bicep') `
    -Type param

Assert-Contract ('codeBuildPrincipalId' -in $primaryParameters) `
    'primary.bicep must accept codeBuildPrincipalId.'
Assert-Contract ('codeDeploymentPrincipalId' -notin $primaryParameters) `
    'primary.bicep unexpectedly accepts codeDeploymentPrincipalId.'
Assert-Contract ('codeDeploymentPrincipalId' -in $secondaryParameters) `
    'secondary.bicep must accept codeDeploymentPrincipalId.'
Assert-Contract ('codeDeploymentPrincipalId' -in $globalParameters) `
    'global.bicep must accept codeDeploymentPrincipalId.'
Assert-Contract (
    $foundationWorkflow -match
        'codeBuildPrincipalId="\$\{\{\s*vars\.LAB06_BUILD_AZURE_PRINCIPAL_ID\s*\}\}"'
) 'Foundation workflow does not pass the build principal to primary.bicep.'
Assert-Contract (
    ([regex]::Matches(
        $foundationWorkflow,
        'codeDeploymentPrincipalId="\$\{\{\s*vars\.LAB06_DEPLOY_AZURE_PRINCIPAL_ID\s*\}\}"'
    )).Count -eq 2
) 'Foundation workflow must pass the deployment principal to secondary.bicep and global.bicep.'
Assert-Contract (
    $foundationWorkflow -notmatch 'LAB06_AZURE_PRINCIPAL_ID'
) 'Foundation workflow still uses the ambiguous LAB06_AZURE_PRINCIPAL_ID variable.'

foreach ($parameter in @(
    'databaseMode',
    'sqlMiPricingModel',
    'sqlEntraAdminObjectId',
    'sqlEntraAdminLogin'
)) {
    Assert-Contract (
        $foundationWorkflow -match [regex]::Escape("$parameter=`"")
    ) "Foundation workflow does not pass '$parameter'."
}

if ($failures.Count -gt 0) {
    throw "Lab 04 OIDC contract validation failed:`n- $($failures -join "`n- ")"
}

Write-Host 'Lab 04 OIDC parameter contracts are valid.'
