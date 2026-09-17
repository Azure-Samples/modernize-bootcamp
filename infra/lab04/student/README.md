# Student starter

Complete the four resource-group-scoped entry points while preserving the
parameter and output contracts documented in `../complete/README.md`:

- `primary.bicep`: primary database VNet, two private VMs, Bastion, private
  Azure SQL, DMS, ACR, and the code identity's ACR-scoped AcrPush assignment.
- `secondary.bicep`: secondary database VNet, the only application VNet
  (`10.20.0.0/20`), one internal zone-redundant workload-profile Container Apps
  environment, database/application peerings and DNS links, app AcrPull, and
  the code identity's app-scoped Container Apps Contributor assignment.
- `global.bicep`: Front Door Premium with one Private Link origin and
  profile-scoped read access for the code-deployment identity.
- `sqlmi.bicep`: optional Entra-only SQL Managed Instance in its dedicated delegated subnet.

Keep API versions stable, do not add public VM IPs, and do not introduce SQL
authentication. The app must keep `minReplicas` at least 2 and use a bounded
`maxReplicas`. Azure SQL's default database name is `eShop`.
