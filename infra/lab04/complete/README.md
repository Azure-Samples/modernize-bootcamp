# Complete Lab 04 Bicep

The known-good implementation uses resource-group-scoped entry points. Deploy
them in this exact order; no subscription-scope deployment is required.

## 1. `primary.bicep`

Parameters:

- `prefix` (default `caldova-lab04`)
- `suffix`
- `location` (default `northcentralus`)
- `codeDeploymentPrincipalId`
- `sqlEntraAdminObjectId`
- `sqlEntraAdminLogin`
- `sqlEntraAdminPrincipalType` (default `User`)
- `vmAdminUsername` (secure)
- `vmAdminPassword` (secure)
- `tags`

Outputs:

- `containerRegistryName`
- `containerRegistryLoginServer`
- `privateDnsZoneName`
- `sqlServerName`
- `sqlServerFqdn`
- `sqlDatabaseName` (default database is `eShop`)
- `databaseVnetId`
- `databaseVnetName`
- `virtualMachineNames`
- `virtualMachineIds`
- `virtualMachinePrincipalIds`

## 2. `secondary.bicep`

Pass the primary deployment's database VNet and SQL private DNS outputs, its
resource group name, registry information, and the code identity principal ID.
This deployment creates the secondary database VNet and the only application
VNet/environment. It creates database-to-database peering, direct
application-to-primary-database peering in both directions, and private SQL DNS
links for both secondary VNets.

Parameters:

- `prefix` (default `caldova-lab04`)
- `suffix`
- `location` (secondary database location; default `centralus`)
- `applicationLocation` (default `centralus`)
- `codeDeploymentPrincipalId`
- `containerRegistryName`
- `containerRegistryResourceGroupName`
- `privateDnsZoneResourceGroupName`
- `privateDnsZoneName`
- `primaryDatabaseResourceGroupName`
- `primaryDatabaseVnetName`
- `primaryDatabaseVnetId`
- `tags`

Outputs:

- `containerAppName`
- `containerAppFqdn`
- `containerAppsEnvironmentId`
- `containerAppsEnvironmentName`
- `applicationVnetId`
- `applicationVnetName`
- `databaseVnetId`
- `databaseVnetName`
- `managedInstanceSubnetId`

## 3. `global.bicep`

Parameters:

- `prefix` (default `caldova-lab04`)
- `suffix`
- `applicationLocation` (default `centralus`)
- `codeDeploymentPrincipalId`
- `originFqdn`
- `containerAppsEnvironmentId`
- `tags`

Outputs:

- `frontDoorEndpointHostName`
- `frontDoorProfileId`

## 4. `sqlmi.bicep` (optional)

Parameters:

- `prefix` (default `caldova-lab04`)
- `suffix`
- `location` (default `centralus`)
- `databaseVnetName`
- `managedInstanceSubnetName`
- `sqlEntraAdminObjectId`
- `sqlEntraAdminLogin`
- `sqlEntraAdminPrincipalType` (default `User`)
- `tags`

Outputs:

- `managedInstanceName`
- `managedInstanceFqdn`

## Design caveats

- The secondary deployment creates primary-side peerings and the SQL private DNS
  link through resource-group-scoped modules. The infrastructure identity
  therefore needs its existing permissions in both regional resource groups.
- The separate code-deployment identity receives only AcrPush
  (`8311e382-0749-4cb8-b61a-304f252e45ec`) on ACR and Container Apps
  Contributor (`358470bc-b998-42bd-ab17-a7e34c199c0f`) on the single app, plus
  Reader on the Front Door profile so the release can resolve and smoke-test
  its endpoint.
  Deterministic role-assignment names make redeployment safe. It receives none
  of the infrastructure identity's broad resource-group roles.
- The bootstrap Key Vault supplies one username/password pair to both VMs. Linux password authentication remains enabled so Azure Bastion can connect over SSH; protect and rotate that credential through Key Vault.
- The SQL MI subnet has a dedicated NSG and route table. SQL Managed Instance service-aided subnet configuration adds and maintains its network-intent rules and routes after delegation; do not replace or block those service-managed entries.
- `publicNetworkAccess` is supported by the stable `Microsoft.App/managedEnvironments@2025-01-01` API. The module uses `union()` to emit it because older local Bicep type metadata can omit that property.
- The application environment is internal, workload-profile based,
  zone-redundant, and has `minReplicas: 2`. Front Door Premium has one Private
  Link origin; its connection request can remain pending until approved.
