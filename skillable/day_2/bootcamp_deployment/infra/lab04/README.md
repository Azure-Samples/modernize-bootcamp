# Lab 04 infrastructure

Lab 04 is an infrastructure-only Azure Developer CLI project. From the
repository root, `azd up` deploys the known-good implementation in `complete/`.

## Provision with AZD

```powershell
azd auth login
azd env new lab04
azd up
```

For Azure CLI validation, what-if, and deployment without AZD, use
[`infra/Deploy-Lab04.ps1`](../Deploy-Lab04.ps1) and follow the
[direct Bicep deployment guide](../DEPLOYMENT.md). A successful direct
deployment approves only the exact expected Front Door Private Link request,
fails closed for unknown or duplicate pending requests, and verifies the public
endpoint. Validation and what-if remain read-only.

The pre-provision hook selects one database target and stores the configuration
in the active AZD environment:

- `sqlMi` (default): Azure SQL Managed Instance in the delegated secondary
  subnet, requesting the Freemium offer.
- `azureSql`: Azure SQL Database with a private endpoint.

If the subscription or region cannot use Freemium, instructor automation can
select the paid General Purpose model:

```powershell
azd env set LAB04_SQL_MI_PRICING_MODEL Regular
azd up --no-prompt
```

The targets are mutually exclusive. Both use Microsoft Entra-only
authentication and contain an `eShop` database. Azure SQL Database disables its
public endpoint. SQL MI enables its public endpoint, but Bicep does not add a
broad TCP 3342 rule; participant access is added later for one public IPv4
address. Database mode is immutable for an AZD environment because incremental
Bicep does not delete resources omitted by a condition. To change modes, run
`azd down --purge` and create a new AZD environment.

## Deployment composition

`infra/main.bicep` is subscription scoped. It creates the bootstrap, primary,
secondary, and global resource groups, then invokes the resource-group-scoped
Lab 04 modules in dependency order:

1. Bootstrap Key Vault and code-deployment managed identity.
2. Primary network, VMs, Bastion, ACR, DMS, and Azure SQL when selected.
3. Secondary database network, application network, Container Apps, monitoring,
   and SQL MI when selected.
4. Front Door Premium with a Private Link origin.

AZD captures the selected database endpoint, resource-group names, ACR and
Container App names, identity IDs, and Front Door endpoint as environment
values. Inspect them with `azd env get-values`.

## Multi-subscription naming

`infra/main.bicep` computes a stable eight-character suffix from the
subscription resource ID, environment name, and prefix. This makes names
different across subscriptions and environments while preserving the same
names on a rerun.

Key Vault, ACR, Azure SQL logical server, SQL Managed Instance, and Front Door
endpoint names all include this shared suffix. The Key Vault prefix is
truncated so the longest allowed input still stays within its 24-character
limit. `LAB04_SUFFIX` exposes the generated value for cleanup and automation.
Supported deployment scripts require a 3-18 character lowercase alphanumeric
prefix with optional single internal hyphens; leading, trailing, and repeated
hyphens are rejected.

## Defaults and address space

| Boundary | Default region | Address space |
| --- | --- | --- |
| Primary database | Central US (`centralus`) | `10.0.0.0/20` |
| Secondary database | Central US (`centralus`) | `10.1.0.0/20` |
| Application | Central US (`centralus`, parameterized) | `10.20.0.0/20` |

The application environment is internal and zone redundant. Front Door Premium
reaches it through Private Link. Database and application VNets are
bidirectionally peered. The primary VMs have no public IP addresses and are
reached through Azure Bastion.

ACR intentionally retains public network access on the Basic SKU so
GitHub-hosted runners can push images. Its administrator account is disabled.
The code-build identity receives only `AcrPush`; the code-deployment identity
receives only Container App update and Front Door read permissions; the
Container App's system identity receives only `AcrPull`.

This is a training deployment, not a production security baseline. See
[Security posture and lab exceptions](../../README.md#security-posture-and-lab-exceptions)
for the public-endpoint inventory, accepted lab trade-offs, production
recommendations, and Azure Landing Zone guidance.

Participants do not run Bicep. After the instructor deployment, they run
`assets/scripts/Enable-Lab04SqlMiPublicAccess.ps1` to create or update a single
TCP 3342 NSG rule for their current public IPv4 `/32`. The participant needs
Network Contributor on the SQL MI NSG only. Supply the public endpoint and
resource names explicitly when the participant does not have Reader access for
automatic discovery.

## Optional GitHub OIDC setup

Azure provisioning does not require GitHub. The setup script is
[`assets/scripts/Configure-Lab04GitHub.ps1`](../../assets/scripts/Configure-Lab04GitHub.ps1).
Run it from the repository root after a successful AZD deployment:

```powershell
Set-Location (git rev-parse --show-toplevel)

.\assets\scripts\Configure-Lab04GitHub.ps1 `
  -SubscriptionId '<subscription-id>' `
  -AzdEnvironment 'lab04' `
  -RequiredReviewer '<github-user-login>' `
  -DeploymentBranch 'main'
```

After a direct Bicep deployment, use its successful subscription deployment
name instead:

```powershell
Set-Location (git rev-parse --show-toplevel)

.\assets\scripts\Configure-Lab04GitHub.ps1 `
  -SubscriptionId '<subscription-id>' `
  -DeploymentName 'lab04-direct-deploy' `
  -RequiredReviewer '<github-user-login>' `
  -DeploymentBranch 'main'
```

Use `-AzdEnvironment` or `-DeploymentName`, not both; one is required. AZD
stores outputs in its local environment, while `Deploy-Lab04.ps1` stores them
on the subscription deployment named `<EnvironmentName>-deploy`. These output
stores are independent. A direct deployment must use `-DeploymentName`, even
when a local AZD environment exists.

Find successful subscription deployments and verify the expected output:

```powershell
az deployment sub list `
  --query "[?properties.provisioningState=='Succeeded'].name" `
  --output table

az deployment sub show `
  --name 'lab04-direct-deploy' `
  --query properties.outputs.LAB04_BOOTSTRAP_RESOURCE_GROUP.value `
  --output tsv
```

The script requires authenticated Azure and GitHub CLIs plus
repository `ADMIN` permission. GitHub `WRITE` permission cannot create or
protect environments. Check the selected repository before setup:

```powershell
gh repo view `
  --json nameWithOwner,viewerPermission `
  --jq '{repository: .nameWithOwner, permission: .viewerPermission}'
```

If necessary, ask an administrator to run the script or use
`-Repository 'owner/name'` to target a repository you administer.

The Lab 04 workflow can then preview and reprovision the same deterministic
environment name, whether the initial deployment used AZD or direct Bicep.
Lab 06 receives the selected database FQDN instead of assuming Azure SQL.
The script creates distinct Lab 04 preview/deploy and Lab 06 build/deploy
identities. Only the deployment environments can mutate runtime resources.
It configures and verifies a required reviewer and an exact deployment branch
for `lab04-deploy` and `lab06-deploy`; setup fails if the repository plan or
permissions cannot enforce those rules.
The setup creates a custom subscription-scoped deployment-operator role that
can run ARM deployments and create or update resource-group shells, but cannot
delete resource groups or manage their contents. Resource creation and
role-assignment permissions remain scoped to the four lab resource groups.
Creating this custom role requires an appropriately privileged operator.
If an older checkout reports `Failed to parse string as JSON` at
`az role definition create`, update the setup script and rerun the same OIDC
command. The corrected script passes a temporary JSON file to Azure CLI instead
of inline JSON, and no Lab 04 infrastructure redeployment is required.

## Validation and cleanup

Build all Bicep files:

```powershell
Get-ChildItem infra -Recurse -Filter *.bicep |
  ForEach-Object { az bicep build --file $_.FullName --stdout | Out-Null }
```

Remove the active environment only after completing dependent labs:

```powershell
azd down --purge
```

AZD environment files can contain generated VM credentials. They are local
state and must never be committed or printed.
