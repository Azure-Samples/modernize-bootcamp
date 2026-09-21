param profileName string
param endpointName string
param originFqdn string
param containerAppsEnvironmentId string
param privateLinkLocation string
param codeDeploymentPrincipalId string
param tags object = {}

var privateLinkRequestMessage = 'Lab04 Front Door origin ${profileName}/${endpointName}/application'
var readerRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  'acdd72a7-3385-48ef-bd42-f606fba81ae7'
)

resource profile 'Microsoft.Cdn/profiles@2024-02-01' = {
  name: profileName
  location: 'global'
  tags: tags
  sku: {
    name: 'Premium_AzureFrontDoor'
  }
  properties: {
    originResponseTimeoutSeconds: 60
  }
}

resource endpoint 'Microsoft.Cdn/profiles/afdEndpoints@2024-02-01' = {
  parent: profile
  name: endpointName
  location: 'global'
  tags: tags
  properties: {
    enabledState: 'Enabled'
  }
}

resource originGroup 'Microsoft.Cdn/profiles/originGroups@2024-02-01' = {
  parent: profile
  name: 'regional-apps'
  properties: {
    healthProbeSettings: {
      probeIntervalInSeconds: 30
      probePath: '/'
      probeProtocol: 'Https'
      probeRequestType: 'HEAD'
    }
    loadBalancingSettings: {
      additionalLatencyInMilliseconds: 50
      sampleSize: 4
      successfulSamplesRequired: 3
    }
    sessionAffinityState: 'Disabled'
  }
}

resource origin 'Microsoft.Cdn/profiles/originGroups/origins@2024-02-01' = {
  parent: originGroup
  name: 'application'
  properties: {
    enabledState: 'Enabled'
    enforceCertificateNameCheck: true
    hostName: originFqdn
    httpPort: 80
    httpsPort: 443
    originHostHeader: originFqdn
    priority: 1
    sharedPrivateLinkResource: {
      groupId: 'managedEnvironments'
      privateLink: {
        id: containerAppsEnvironmentId
      }
      privateLinkLocation: privateLinkLocation
      requestMessage: privateLinkRequestMessage
    }
    weight: 1000
  }
}

resource route 'Microsoft.Cdn/profiles/afdEndpoints/routes@2024-02-01' = {
  parent: endpoint
  name: 'default'
  dependsOn: [
    origin
  ]
  properties: {
    enabledState: 'Enabled'
    forwardingProtocol: 'HttpsOnly'
    httpsRedirect: 'Enabled'
    linkToDefaultDomain: 'Enabled'
    originGroup: {
      id: originGroup.id
    }
    patternsToMatch: [
      '/*'
    ]
    supportedProtocols: [
      'Http'
      'Https'
    ]
  }
}

resource codeDeploymentReader 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(profile.id, codeDeploymentPrincipalId, readerRoleDefinitionId)
  scope: profile
  properties: {
    roleDefinitionId: readerRoleDefinitionId
    principalId: codeDeploymentPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output endpointHostName string = endpoint.properties.hostName
output profileId string = profile.id
output originId string = origin.id
output privateLinkRequestMessage string = privateLinkRequestMessage
