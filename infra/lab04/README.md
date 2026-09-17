# Lab 04 infrastructure

This tree contains resource-group-scoped Bicep for the deployment lab.
`student/` is a compiling starter with the same entry-point contracts as the
known-good modular implementation in `complete/`.

Deploy the entry points in this exact order:

1. `primary.bicep` in the primary resource group.
2. `secondary.bicep` in the secondary resource group, passing primary outputs.
3. `global.bicep` in the global resource group, passing secondary app outputs.
4. `sqlmi.bicep` in the secondary resource group only when SQL MI is requested.

All entry points target an existing resource group. The bootstrap script creates the resource groups, OIDC identity, RBAC-enabled Key Vault, and VM credentials before a workflow runs.

## Defaults and address space

| Boundary | Default region | Address space |
| --- | --- | --- |
| Primary database | North Central US (`northcentralus`) | `10.0.0.0/20` |
| Secondary database | Central US (`centralus`) | `10.1.0.0/20` |
| Application | Central US (`centralus`, parameterized) | `10.20.0.0/20` |

There is one internal, zone-redundant workload-profile Container Apps
environment and one application VNet. Front Door Premium uses one Private Link
origin. Direct bidirectional peering and a private DNS link let the application
VNet resolve and reach the primary private Azure SQL endpoint. Database VNets
remain bidirectionally peered. The two primary-region VMs have no public IPs and
are reached through Azure Bastion.

The bootstrap publishes `LAB04_APPLICATION_LOCATION` (default `centralus`) for
workflows to pass as `applicationLocation`. It also creates a separate code
identity federated to `lab06` and `lab06-deploy`. Pass
`LAB06_AZURE_PRINCIPAL_ID` as `codeDeploymentPrincipalId` to `primary.bicep`
and `secondary.bicep`. Bicep grants only AcrPush on the registry and Container
Apps Contributor on the app; the app system identity retains AcrPull.

## Secure inputs

Never place credentials in parameter files. Resolve the bootstrap secrets at workflow runtime and pass them directly to the primary resource-group deployment:

```powershell
$vmUser = az keyvault secret show --vault-name $env:LAB04_KEY_VAULT_NAME --name vm-admin-username --query value -o tsv
$vmPassword = az keyvault secret show --vault-name $env:LAB04_KEY_VAULT_NAME --name vm-admin-password --query value -o tsv
az deployment group create --resource-group $env:LAB04_PRIMARY_RESOURCE_GROUP --template-file infra/lab04/complete/primary.bicep --parameters vmAdminUsername=$vmUser vmAdminPassword=$vmPassword
```

`vmAdminPassword` is declared with `@secure()`. Azure SQL and optional SQL Managed Instance use Microsoft Entra-only authentication and accept no SQL authentication credentials.

## Local validation

Build every Bicep file:

```powershell
Get-ChildItem infra/lab04 -Recurse -Filter *.bicep |
  ForEach-Object { az bicep build --file $_.FullName --stdout | Out-Null }
```

Building checks syntax and type safety; it does not create Azure resources.
