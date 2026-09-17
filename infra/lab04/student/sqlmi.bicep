targetScope = 'resourceGroup'

@minLength(3)
@maxLength(18)
param prefix string = 'caldova-lab04'

@minLength(6)
@maxLength(6)
param suffix string

param location string = 'centralus'
param databaseVnetName string = '${prefix}-db-secondary-${suffix}-vnet'
param managedInstanceSubnetName string = 'snet-sqlmi'
param sqlEntraAdminObjectId string
param sqlEntraAdminLogin string

@allowed([
  'User'
  'Group'
  'Application'
])
param sqlEntraAdminPrincipalType string = 'User'

param tags object = {
  Application: 'Caldova'
  Environment: 'Lab'
  ManagedBy: 'Bicep'
  Optional: 'SqlManagedInstance'
}

// TODO: Deploy an optional private SQL Managed Instance with Entra-only authentication.

output managedInstanceName string = ''
output managedInstanceFqdn string = ''
