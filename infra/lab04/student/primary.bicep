targetScope = 'resourceGroup'

@description('Lowercase lab prefix used in resource names.')
@minLength(3)
@maxLength(18)
param prefix string = 'caldova-lab04'

@description('Six-character suffix produced by the bootstrap script.')
@minLength(6)
@maxLength(6)
param suffix string

param location string = 'northcentralus'
param codeDeploymentPrincipalId string
param sqlEntraAdminObjectId string
param sqlEntraAdminLogin string

@allowed([
  'User'
  'Group'
  'Application'
])
param sqlEntraAdminPrincipalType string = 'User'

@secure()
param vmAdminUsername string

@secure()
param vmAdminPassword string

param tags object = {
  Application: 'Caldova'
  Environment: 'Lab'
  ManagedBy: 'Bicep'
}

// TODO: Compose the primary database, VM, SQL, DMS, ACR, and AcrPush modules here.

output containerRegistryName string = ''
output containerRegistryLoginServer string = ''
output privateDnsZoneName string = 'privatelink${environment().suffixes.sqlServerHostname}'
output sqlServerName string = ''
output sqlServerFqdn string = ''
output sqlDatabaseName string = 'eShop'
output databaseVnetId string = ''
output databaseVnetName string = ''
output virtualMachineNames array = []
output virtualMachineIds array = []
output virtualMachinePrincipalIds array = []
