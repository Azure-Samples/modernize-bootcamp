# Complete Lab 04 Bicep

The known-good implementation is composed by the subscription-scoped
`infra/main.bicep` entry point used by Azure Developer CLI. The files in this
directory remain resource-group scoped and can still be built independently.

## Entry points

### `bootstrap.bicep`

Creates the RBAC-enabled Key Vault, VM credential secrets, and separate code
build and deployment managed identities. It grants the selected Microsoft Entra
administrator Key Vault Secrets Officer.

### `primary.bicep`

Creates the primary database VNet, two private VMs, Bastion, ACR, DMS, and
workload role assignments. Its `databaseMode` parameter controls Azure SQL:

- `azureSql`: create the Entra-only S0 `eShop` database, private endpoint,
  private DNS zone, and VNet link.
- `sqlMi`: omit all Azure SQL logical server and database resources.

### `secondary.bicep`

Creates the secondary database and application VNets, peerings, Log Analytics,
the internal zone-redundant Container Apps environment, and the placeholder
Container App.

- `azureSql`: link the application and secondary VNets to the primary SQL
  private DNS zone.
- `sqlMi`: create the delegated SQL MI subnet, General Purpose Gen5 managed
  instance, and `eShop` managed database.

The entry point returns a unified database FQDN, name, and type.

### `global.bicep`

Creates Front Door Premium, its endpoint and route, and one Private Link origin
targeting the Container Apps environment.

### `sqlmi.bicep`

Retained as a standalone compatibility entry point. The AZD path does not call
it because SQL MI is now selected exclusively through `databaseMode`.

## Design caveats

- SQL MI requires a dedicated delegated subnet, NSG, route table, available
  regional quota, explicit cost confirmation, and a long provisioning window.
- The optional GitHub setup creates separate infrastructure preview and
  deployment identities. Preview receives Reader on the four lab resource
  groups. Only deployment receives the custom subscription deployment role,
  Contributor, RBAC Administrator, and Key Vault Secrets User.
- The code-build identity receives only ACR push. The code-deployment identity
  receives only Container App contributor and Front Door reader permissions at
  resource scope.
- Deployment environments require a reviewer and exact branch policy. GitHub
  setup verifies both controls and stops when they cannot be enforced.
- The workflow approves only the expected Front Door Private Link request and
  fails closed when unknown or duplicate pending requests are present.
- ACR stays publicly reachable for GitHub-hosted runners, with its administrator
  account disabled. Private ACR would require Premium, Private Link/DNS, and a
  VNet-connected build runner or ACR Tasks.
- The Container Apps environment is internal, zone redundant, and reached by
  Front Door through Private Link.
