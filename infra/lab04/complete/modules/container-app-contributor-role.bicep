param containerAppName string
param principalId string

var containerAppsContributorRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '358470bc-b998-42bd-ab17-a7e34c199c0f'
)

resource app 'Microsoft.App/containerApps@2024-03-01' existing = {
  name: containerAppName
}

resource assignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(app.id, principalId, containerAppsContributorRoleDefinitionId)
  scope: app
  properties: {
    roleDefinitionId: containerAppsContributorRoleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}
