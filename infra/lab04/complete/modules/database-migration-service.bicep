param name string
param location string
param subnetId string
param tags object = {}

resource service 'Microsoft.DataMigration/services@2025-06-30' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard_1vCore'
    tier: 'Standard'
    size: '1 vCore'
  }
  properties: {
    virtualSubnetId: subnetId
  }
}

output id string = service.id
output name string = service.name
