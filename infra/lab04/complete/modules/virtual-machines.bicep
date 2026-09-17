param prefix string
param suffix string
param location string
param subnetId string

@secure()
param adminUsername string

@secure()
param adminPassword string

param tags object = {}

resource sourceNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${prefix}-source-${suffix}-nic'
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource testNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${prefix}-test-${suffix}-nic'
  location: location
  tags: tags
  properties: {
    enableAcceleratedNetworking: false
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}

resource sourceVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${prefix}-source-${suffix}-vm'
  location: location
  tags: union(tags, {
    WorkloadRole: 'source'
    OperatingSystem: 'Windows'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: sourceNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      computerName: 'lab-source'
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          enableHotpatching: false
          patchMode: 'AutomaticByPlatform'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: 'sql2022-ws2022'
        sku: 'sqldev-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

resource testVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${prefix}-test-${suffix}-vm'
  location: location
  tags: union(tags, {
    WorkloadRole: 'test'
    OperatingSystem: 'Linux'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_D2s_v5'
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: testNic.id
          properties: {
            primary: true
          }
        }
      ]
    }
    osProfile: {
      computerName: 'lab-test'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
        provisionVMAgent: true
        patchSettings: {
          assessmentMode: 'AutomaticByPlatform'
          patchMode: 'AutomaticByPlatform'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    securityProfile: {
      securityType: 'TrustedLaunch'
      uefiSettings: {
        secureBootEnabled: true
        vTpmEnabled: true
      }
    }
  }
}

output virtualMachineIds array = [
  sourceVm.id
  testVm.id
]
output virtualMachineNames array = [
  sourceVm.name
  testVm.name
]
output virtualMachinePrincipalIds array = [
  sourceVm.identity.principalId
  testVm.identity.principalId
]
