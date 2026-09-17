targetScope = 'resourceGroup'

@minLength(3)
@maxLength(18)
param prefix string = 'caldova-lab04'

@minLength(6)
@maxLength(6)
param suffix string

param applicationLocation string = 'centralus'
param codeDeploymentPrincipalId string
param originFqdn string
param containerAppsEnvironmentId string

param tags object = {
  Application: 'Caldova'
  Environment: 'Lab'
  ManagedBy: 'Bicep'
}

var nameToken = take(replace(prefix, '-', ''), 12)

module frontDoor './modules/front-door.bicep' = {
  name: 'front-door'
  params: {
    profileName: '${prefix}-${suffix}-afd'
    endpointName: '${nameToken}-${suffix}'
    originFqdn: originFqdn
    containerAppsEnvironmentId: containerAppsEnvironmentId
    privateLinkLocation: applicationLocation
    codeDeploymentPrincipalId: codeDeploymentPrincipalId
    tags: tags
  }
}

output frontDoorEndpointHostName string = frontDoor.outputs.endpointHostName
output frontDoorProfileId string = frontDoor.outputs.profileId
