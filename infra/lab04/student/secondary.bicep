targetScope = 'resourceGroup'

@minLength(3)
@maxLength(18)
param prefix string = 'caldova-lab04'

@minLength(6)
@maxLength(6)
param suffix string

param location string = 'centralus'
param applicationLocation string = 'centralus'
param codeDeploymentPrincipalId string
param containerRegistryName string
param containerRegistryResourceGroupName string
param privateDnsZoneResourceGroupName string
param privateDnsZoneName string = 'privatelink${environment().suffixes.sqlServerHostname}'
param primaryDatabaseResourceGroupName string
param primaryDatabaseVnetName string
param primaryDatabaseVnetId string

param tags object = {
  Application: 'Caldova'
  Environment: 'Lab'
  ManagedBy: 'Bicep'
}

// TODO: Compose the secondary database network, single application network/environment, private connectivity, and app-scoped role modules here.

output containerAppName string = ''
output containerAppFqdn string = ''
output containerAppsEnvironmentId string = ''
output containerAppsEnvironmentName string = ''
output applicationVnetId string = ''
output applicationVnetName string = ''
output databaseVnetId string = ''
output databaseVnetName string = ''
output managedInstanceSubnetId string = ''
