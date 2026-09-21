targetScope = 'resourceGroup'

@minLength(3)
@maxLength(18)
param prefix string

@minLength(8)
@maxLength(8)
param suffix string
param location string
param keyVaultAdministratorObjectId string

@secure()
param vmAdminUsername string

@secure()
param vmAdminPassword string

param tags object = {}

var safePrefix = take(replace(prefix, '-', ''), 13)
var keyVaultName = toLower('${safePrefix}${suffix}-kv')
var codeBuildIdentityName = '${prefix}-code-build-${suffix}'
var codeDeploymentIdentityName = '${prefix}-code-deploy-${suffix}'
var keyVaultSecretsOfficerRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
)

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    enableRbacAuthorization: true
    enableSoftDelete: true
    publicNetworkAccess: 'Enabled'
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
  }
}

resource vmUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'vm-admin-username'
  properties: {
    value: vmAdminUsername
  }
}

resource vmPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'vm-admin-password'
  properties: {
    value: vmAdminPassword
  }
}

resource codeBuildIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: codeBuildIdentityName
  location: location
  tags: tags
}

resource codeDeploymentIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: codeDeploymentIdentityName
  location: location
  tags: tags
}

resource secretsOfficerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, keyVaultAdministratorObjectId, keyVaultSecretsOfficerRoleDefinitionId)
  scope: keyVault
  properties: {
    roleDefinitionId: keyVaultSecretsOfficerRoleDefinitionId
    principalId: keyVaultAdministratorObjectId
    principalType: 'User'
  }
}

output keyVaultName string = keyVault.name
output codeBuildIdentityName string = codeBuildIdentity.name
output codeBuildClientId string = codeBuildIdentity.properties.clientId
output codeBuildPrincipalId string = codeBuildIdentity.properties.principalId
output codeDeploymentIdentityName string = codeDeploymentIdentity.name
output codeDeploymentClientId string = codeDeploymentIdentity.properties.clientId
output codeDeploymentPrincipalId string = codeDeploymentIdentity.properties.principalId
