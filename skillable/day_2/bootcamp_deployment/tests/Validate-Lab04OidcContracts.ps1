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
$documentationPaths = @(
    (Join-Path $projectRoot 'README.md'),
    (Join-Path $projectRoot 'infra\DEPLOYMENT.md'),
    (Join-Path $projectRoot 'infra\lab04\README.md')
)

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

function Get-CommandParameterSet {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name
    )

    return Get-Command -Name $Path |
        Select-Object -ExpandProperty ParameterSets |
        Where-Object Name -EQ $Name
}

function Get-ParameterAttribute {
    param(
        [Parameter(Mandatory)][System.Management.Automation.CommandInfo]$Command,
        [Parameter(Mandatory)][string]$ParameterName,
        [Parameter(Mandatory)][type]$AttributeType
    )

    return $Command.Parameters[$ParameterName].Attributes |
        Where-Object { $_ -is $AttributeType }
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
$configureCommand = Get-Command -Name $configureScriptPath

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

$expectedConfigureParameterSets = @{
    Azd = @('SubscriptionId', 'AzdEnvironment', 'RequiredReviewer')
    Arm = @('SubscriptionId', 'DeploymentName', 'RequiredReviewer')
}
foreach ($entry in $expectedConfigureParameterSets.GetEnumerator()) {
    $parameterSet = Get-CommandParameterSet `
        -Path $configureScriptPath `
        -Name $entry.Key
    Assert-Contract ($null -ne $parameterSet) `
        "Configure-Lab04GitHub.ps1 is missing parameter set '$($entry.Key)'."
    if ($null -eq $parameterSet) {
        continue
    }

    $mandatoryParameters = @(
        $parameterSet.Parameters |
            Where-Object IsMandatory |
            ForEach-Object Name |
            Sort-Object
    )
    $expectedMandatoryParameters = @($entry.Value | Sort-Object)
    Assert-Contract (
        @(
            Compare-Object $mandatoryParameters $expectedMandatoryParameters
        ).Count -eq 0
    ) "Configure-Lab04GitHub.ps1 parameter set '$($entry.Key)' has incorrect mandatory parameters. Expected: $($expectedMandatoryParameters -join ', '). Actual: $($mandatoryParameters -join ', ')."
}

$azdParameterSet = Get-CommandParameterSet `
    -Path $configureScriptPath `
    -Name 'Azd'
$armParameterSet = Get-CommandParameterSet `
    -Path $configureScriptPath `
    -Name 'Arm'
Assert-Contract (
    $null -ne $azdParameterSet -and
    'DeploymentName' -notin @($azdParameterSet.Parameters.Name)
) 'The Azd parameter set must not accept DeploymentName.'
Assert-Contract (
    $null -ne $armParameterSet -and
    'AzdEnvironment' -notin @($armParameterSet.Parameters.Name)
) 'The Arm parameter set must not accept AzdEnvironment.'

$expectedConfigureValidation = @{
    SubscriptionId = [System.Management.Automation.ValidatePatternAttribute]
    Repository = [System.Management.Automation.ValidatePatternAttribute]
    AzdEnvironment = [System.Management.Automation.ValidateNotNullOrEmptyAttribute]
    DeploymentName = [System.Management.Automation.ValidatePatternAttribute]
    GitHubEnvironment = [System.Management.Automation.ValidatePatternAttribute]
    RequiredReviewer = [System.Management.Automation.ValidatePatternAttribute]
    DeploymentBranch = [System.Management.Automation.ValidateNotNullOrEmptyAttribute]
}
foreach ($entry in $expectedConfigureValidation.GetEnumerator()) {
    $attribute = Get-ParameterAttribute `
        -Command $configureCommand `
        -ParameterName $entry.Key `
        -AttributeType $entry.Value
    Assert-Contract ($null -ne $attribute) `
        "Configure-Lab04GitHub.ps1 parameter '$($entry.Key)' is missing $($entry.Value.Name)."
}

$expectedConfigureLengths = @{
    DeploymentName = @(1, 64)
    GitHubEnvironment = @(1, 106)
    RequiredReviewer = @(1, 39)
}
foreach ($entry in $expectedConfigureLengths.GetEnumerator()) {
    $attribute = Get-ParameterAttribute `
        -Command $configureCommand `
        -ParameterName $entry.Key `
        -AttributeType ([System.Management.Automation.ValidateLengthAttribute])
    Assert-Contract (
        $null -ne $attribute -and
        $attribute.MinLength -eq $entry.Value[0] -and
        $attribute.MaxLength -eq $entry.Value[1]
    ) "Configure-Lab04GitHub.ps1 parameter '$($entry.Key)' must have a length range of $($entry.Value[0])-$($entry.Value[1])."
}

$deployScript = Get-Content -LiteralPath $deployScriptPath -Raw
Assert-Contract (
    $deployScript -match '\$armDeploymentName\s*=\s*if\s*\(\$DeploymentName\)'
) 'Deploy-Lab04.ps1 does not honor the optional DeploymentName override.'
Assert-Contract (
    $deployScript -match '"\$EnvironmentName-deploy"'
) 'Deploy-Lab04.ps1 no longer defaults to <EnvironmentName>-deploy.'
Assert-Contract (
    $deployScript -match 'Split-Path -Parent \$PSScriptRoot' -and
    $deployScript -match '''assets\\scripts\\Configure-Lab04GitHub\.ps1'''
) 'Deploy-Lab04.ps1 does not generate a working-directory-independent OIDC setup path.'
Assert-Contract (
    $deployScript -match 'Write-Host\s+"& ''\$configureScriptPath''' -and
    $deployScript -match '-DeploymentName ''\$armDeploymentName'''
) 'Deploy-Lab04.ps1 does not print a copyable OIDC setup command with DeploymentName.'

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

$deploymentParametersMatch = [regex]::Match(
    $deployScript,
    '(?s)\$deploymentParameters\s*=\s*@\((.*?)\)\s*\r?\n\r?\ntry'
)
Assert-Contract $deploymentParametersMatch.Success `
    'Could not locate the direct deployment parameter mapping in Deploy-Lab04.ps1.'
$directDeploymentParameters = @(
    [regex]::Matches(
        $deploymentParametersMatch.Groups[1].Value,
        '"([A-Za-z0-9_]+)='
    ) | ForEach-Object { $_.Groups[1].Value }
)
foreach ($name in $mainParameters) {
    Assert-Contract ($name -in $directDeploymentParameters) `
        "Deploy-Lab04.ps1 does not pass main.bicep parameter '$name'."
}
foreach ($name in $directDeploymentParameters) {
    Assert-Contract ($name -in $mainParameters) `
        "Deploy-Lab04.ps1 passes unknown main.bicep parameter '$name'."
}

$expectedProjectLocationCommand = "Set-Location (Join-Path (git rev-parse --show-toplevel) 'skillable\day_2\bootcamp_deployment')"
foreach ($documentationPath in $documentationPaths) {
    $documentation = Get-Content -LiteralPath $documentationPath -Raw
    Assert-Contract (
        $documentation.Contains($expectedProjectLocationCommand)
    ) "$(Split-Path -Leaf $documentationPath) does not identify the working directory required by its relative OIDC setup command."
    Assert-Contract (
        $documentation -match 'Get-Command .*?Configure-Lab04GitHub\.ps1'
    ) "$(Split-Path -Leaf $documentationPath) does not explain how to diagnose a stale OIDC setup script."
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
