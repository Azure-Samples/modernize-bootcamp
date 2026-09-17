targetScope = 'resourceGroup'

@minLength(3)
@maxLength(18)
param prefix string = 'caldova-lab04'

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

var nameToken = take(replace(prefix, '-', ''), 12)
var registryName = toLower('${nameToken}cr${suffix}')
var sqlServerName = toLower('${nameToken}sql${suffix}')

module network './modules/regional-network.bicep' = {
  name: 'primary-network'
  params: {
    prefix: prefix
    suffix: suffix
    regionLabel: 'primary'
    location: location
    databaseAddressPrefix: '10.0.0.0/20'
    applicationAddressPrefix: '10.20.0.0/20'
    enablePrimaryServices: true
    enableApplicationVnet: false
    tags: tags
  }
}

module registry './modules/container-registry.bicep' = {
  name: 'container-registry'
  params: {
    name: registryName
    location: location
    tags: tags
  }
}

module codeDeploymentRegistryPush './modules/acr-push-role.bicep' = {
  name: 'code-deployment-acr-push'
  params: {
    containerRegistryName: registry.outputs.name
    principalId: codeDeploymentPrincipalId
  }
}

module machines './modules/virtual-machines.bicep' = {
  name: 'private-virtual-machines'
  params: {
    prefix: prefix
    suffix: suffix
    location: location
    subnetId: network.outputs.vmSubnetId
    adminUsername: vmAdminUsername
    adminPassword: vmAdminPassword
    tags: tags
  }
}

module bastion './modules/bastion.bicep' = {
  name: 'bastion'
  params: {
    name: '${prefix}-${suffix}-bas'
    location: location
    subnetId: network.outputs.bastionSubnetId
    tags: tags
  }
}

module sql './modules/sql-database.bicep' = {
  name: 'private-sql-database'
  params: {
    serverName: sqlServerName
    location: location
    entraAdminObjectId: sqlEntraAdminObjectId
    entraAdminLogin: sqlEntraAdminLogin
    entraAdminPrincipalType: sqlEntraAdminPrincipalType
    privateEndpointSubnetId: network.outputs.privateEndpointSubnetId
    databaseVnetId: network.outputs.databaseVnetId
    tags: tags
  }
}

module migration './modules/database-migration-service.bicep' = {
  name: 'database-migration-service'
  params: {
    name: '${prefix}-${suffix}-dms'
    location: location
    subnetId: network.outputs.dmsSubnetId
    tags: tags
  }
}

output containerRegistryName string = registry.outputs.name
output containerRegistryLoginServer string = registry.outputs.loginServer
output privateDnsZoneName string = sql.outputs.privateDnsZoneName
output sqlServerName string = sql.outputs.serverName
output sqlServerFqdn string = sql.outputs.serverFqdn
output sqlDatabaseName string = sql.outputs.databaseName
output databaseVnetId string = network.outputs.databaseVnetId
output databaseVnetName string = network.outputs.databaseVnetName
output virtualMachineNames array = machines.outputs.virtualMachineNames
output virtualMachineIds array = machines.outputs.virtualMachineIds
output virtualMachinePrincipalIds array = machines.outputs.virtualMachinePrincipalIds
