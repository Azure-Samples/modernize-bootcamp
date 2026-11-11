param name string
param location string
param tags object = {}

resource service 'Microsoft.DataMigration/sqlMigrationServices@2025-06-30' = {
  name: name
  location: location
  tags: tags
  properties: {}
}

output id string = service.id
output name string = service.name
