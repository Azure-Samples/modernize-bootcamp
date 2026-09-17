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

// TODO: Deploy Front Door Premium with one Private Link origin.

output frontDoorEndpointHostName string = ''
output frontDoorProfileId string = ''
