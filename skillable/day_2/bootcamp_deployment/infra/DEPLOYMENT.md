# Deploy Lab 04 Bicep directly

The recommended deployment path is `azd up`, but the subscription-scoped
[`main.bicep`](./main.bicep) entry point can also be executed directly with
Azure CLI. Direct deployment bypasses AZD hooks and does not save Bicep outputs
in an AZD environment.

Run every command from the repository root.

## Prerequisites

- Azure CLI installed and authenticated with `az login`.
- Permission to create subscription deployments and resource groups.
- Contributor and role-assignment permissions in the four generated resource
  groups.
- Regional availability and quota for the selected resources.

## Use the deployment script

The script prompts securely for the VM administrator password, resolves the
signed-in Microsoft Entra user for SQL administration, validates the object ID,
and never writes the password to a parameter file.

The password must be 12-72 characters, must not contain the VM administrator
username, and must contain lowercase, uppercase, numeric, and at least one of
`! @ $ % * _ - + =`. Restricting input to these characters avoids the
differences between Windows and Linux password rules and native CLI quoting.

The deployment derives a deterministic eight-character resource suffix from
the subscription resource ID, `EnvironmentName`, and `Prefix`. Deploying the
same environment name and prefix to another subscription produces a different
suffix for globally unique resources. Rerunning in the same subscription with
the same inputs reuses the original names.

`Prefix` must be 3-18 lowercase alphanumeric characters with optional single
internal hyphens, and it must begin and end with an alphanumeric character.

Set your subscription:

```powershell
$subscriptionId = '<subscription-id>'
az login
```

If Microsoft Graph reports `InteractionRequired` or
`TokenCreatedWithOutdatedPolicies`, the ARM token is still cached but the Graph
token no longer satisfies current Conditional Access policy. Reauthenticate
interactively for the subscription tenant:

```powershell
$tenantId = az account show --query tenantId --output tsv
az login --tenant $tenantId
az account set --subscription $subscriptionId
az ad signed-in-user show --output table
```

If browser authentication is unavailable, use
`az login --tenant $tenantId --use-device-code`. Do not use a service principal
for the default signed-in-user lookup. Alternatively, pass both
`-SqlEntraAdminObjectId` and `-SqlEntraAdminLogin` to the deployment script to
skip the Microsoft Graph request.

Validate the template and parameters:

```powershell
.\infra\Deploy-Lab04.ps1 `
  -SubscriptionId $subscriptionId `
  -EnvironmentName 'lab04-direct' `
  -Action Validate
```

Preview the changes without deploying:

```powershell
.\infra\Deploy-Lab04.ps1 `
  -SubscriptionId $subscriptionId `
  -EnvironmentName 'lab04-direct' `
  -Action WhatIf
```

Deploy after reviewing the interactive what-if result:

```powershell
.\infra\Deploy-Lab04.ps1 `
  -SubscriptionId $subscriptionId `
  -EnvironmentName 'lab04-direct' `
  -Action Deploy
```

`Deploy` runs `az deployment sub create --confirm-with-what-if`, so Azure CLI
asks for confirmation before changing resources. After a successful deployment,
the script automatically:

1. reads the managed environment, Front Door origin, request message, and
   endpoint from the ARM deployment outputs
2. waits for exactly one Private Link request with the expected Front Door
   request message
3. refuses to approve anything if an unknown pending or duplicate matching
   request exists
4. approves only the exact expected request, or accepts it if already approved
5. verifies the connection state and waits for a successful HTTPS response from
   Front Door

The operator therefore needs permission to approve private endpoint connections
on the Container Apps managed environment. Validation and what-if actions never
approve a connection.

This automatic approval is a lab convenience because the same reviewed
deployment creates both ends and the request is bound to deterministic output.
Production landing zones should normally keep Private Link approval as a
separate protected action unless an equivalently constrained deployment
identity and policy-approved automation path are in place.

## Configure optional GitHub OIDC

The deployment script names the subscription deployment
`<EnvironmentName>-deploy` and prints a copyable OIDC setup command after a
successful deployment. Direct deployment outputs are stored on that ARM
deployment; they are not copied into an AZD environment.

For the default `lab04-direct` environment, run this from the repository root:

```powershell
.\assets\scripts\Configure-Lab04GitHub.ps1 `
  -SubscriptionId $subscriptionId `
  -DeploymentName 'lab04-direct-deploy' `
  -RequiredReviewer '<github-user-login>' `
  -DeploymentBranch 'main'
```

The authenticated GitHub account needs `ADMIN` permission on the repository;
`WRITE` permission is not sufficient for the environments API. Confirm the
automatically selected target before running setup:

```powershell
gh repo view `
  --json nameWithOwner,viewerPermission `
  --jq '{repository: .nameWithOwner, permission: .viewerPermission}'
```

If needed, have a repository administrator run the setup or add
`-Repository 'owner/name'` for a repository you administer.

Do not use `-AzdEnvironment` for infrastructure created by
`Deploy-Lab04.ps1`. To locate the generated ARM deployment and verify its
outputs:

```powershell
az deployment sub list `
  --query "[?properties.provisioningState=='Succeeded'].name" `
  --output table

az deployment sub show `
  --name 'lab04-direct-deploy' `
  --query properties.outputs.LAB04_BOOTSTRAP_RESOURCE_GROUP.value `
  --output tsv
```

If an older checkout fails at `az role definition create` with
`Failed to parse string as JSON`, Windows PowerShell stripped quotes from the
inline JSON argument before Azure CLI parsed it. Update
`assets/scripts/Configure-Lab04GitHub.ps1` and rerun the same OIDC setup
command. The corrected script uses a temporary JSON file and cleans it up;
there is no need to redeploy Lab 04.

## Select regions

The primary, secondary, and application locations are independent parameters:

```powershell
.\infra\Deploy-Lab04.ps1 `
  -SubscriptionId $subscriptionId `
  -EnvironmentName 'lab04-direct' `
  -PrimaryLocation 'centralus' `
  -SecondaryLocation 'eastus2' `
  -ApplicationLocation 'centralus' `
  -Action WhatIf
```

Confirm SQL, VM, DMS, SQL MI, and zone-redundant Container Apps availability
before deploying to different regions. Locations cannot be changed in place for
existing regional resources. Use a new environment name or remove the old
deployment first.

## Select the database target

Azure SQL Database is the default:

```powershell
.\infra\Deploy-Lab04.ps1 `
  -SubscriptionId $subscriptionId `
  -DatabaseMode azureSql `
  -Action Deploy
```

SQL Managed Instance is mutually exclusive, expensive, and can take hours. It
requires explicit cost confirmation:

```powershell
.\infra\Deploy-Lab04.ps1 `
  -SubscriptionId $subscriptionId `
  -EnvironmentName 'lab04-direct-sqlmi' `
  -DatabaseMode sqlMi `
  -ConfirmSqlMiCost `
  -Action Deploy
```

Do not switch database modes for an existing environment name. Conditional
Bicep resources omitted during an incremental deployment are not automatically
deleted.

## Use a different Entra administrator

By default, the script uses the signed-in Entra user. For a different Entra
user, pass the user's object ID and login name:

```powershell
.\infra\Deploy-Lab04.ps1 `
  -SubscriptionId $subscriptionId `
  -SqlEntraAdminObjectId '<object-guid>' `
  -SqlEntraAdminLogin '<display-or-login-name>' `
  -Action WhatIf
```

The object ID must be a GUID. Do not pass a PowerShell object expression such
as `$entraUser.id` directly inside a native command argument; assign it to a
string variable first.

## Reruns and diagnostics

Deployments are deterministic for the subscription, environment name, and
prefix, so a failed deployment can normally be corrected and rerun with the
same values.

A `ReferencedResourceNotProvisioned` error that reports an application VNet in
`Updating` state during `PutSubnetOperation` is a deployment-order race. The
network module sequences the reciprocal peerings after subnet completion; rerun
the same deployment after applying the current module.

A `ManagedEnvironmentInvalidSchema` error on API `2025-01-01` can result from
properties that are absent from that API's managed-environment schema. The
environment uses `vnetConfiguration.internal: true` for private ingress and
does not inject unsupported properties. The generated Container App name is
also bounded to the service's 32-character limit.

`ManagedEnvironmentCapacityHeavyUsageError` or `AKSCapacityHeavyUsage` means
the Container Apps control plane cannot currently allocate backing capacity in
the selected application region. It is not an ARM schema or quota error. Retry
later, or select another region that supports the Consumption workload profile.
Because the application VNet is regional, delete the failed managed environment
and application VNet before changing `ApplicationLocation` for the same
environment name. Confirm every resolved resource ID before deletion.

If Azure Database Migration Service fails while provisioning its managed
`IaaSAntimalware` VM extension, first rerun the same deployment. The backing VM
and extension are created by the DMS resource provider and are not controlled
by this Bicep template. If the same failure repeats, inspect the failed DMS
operation and inherited Azure Policy assignments, try another supported region,
or open an Azure support request.

The DMS resource explicitly declares the immutable classic-service kind as
`Cloud`. This is required for idempotent retries because Azure retains a failed
DMS resource and rejects later requests that omit or change its kind.

If the retained DMS resource remains in terminal `Failed` state and has no
`virtualNicId`, it cannot resume. Delete only that failed DMS resource, wait for
deletion to complete, and rerun the full deployment:

```powershell
$dmsId = az resource list `
  --resource-group 'rg-caldova-lab04-primary-<suffix>' `
  --resource-type 'Microsoft.DataMigration/services' `
  --query '[0].id' `
  --output tsv

az resource delete --ids $dmsId --api-version 2025-06-30
az resource wait --deleted --ids $dmsId --api-version 2025-06-30
```

Confirm the resolved resource ID before running the delete command. This
recreates only DMS; the successfully deployed Lab 04 resources remain intact.

Inspect failed subscription operations:

```powershell
az deployment operation sub list `
  --name 'lab04-direct-deploy' `
  --query "[?properties.provisioningState=='Failed']" `
  --output table
```

List resources created for the direct deployment:

```powershell
az resource list `
  --tag azd-env-name=lab04-direct `
  --output table
```

Direct deployment does not create AZD state. Cleanup must be performed by
reviewing and deleting the four generated Lab 04 resource groups. Do not delete
resource groups until dependent labs are complete.
