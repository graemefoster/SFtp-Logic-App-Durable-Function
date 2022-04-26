targetScope = 'resourceGroup'

param name string = 'test'
param location string = resourceGroup().location

var uniqueName = '${name}${substring(uniqueString(resourceGroup().id), 0, 5)}'

resource sftp 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${uniqueName}sftp'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
    isLocalUserEnabled: true
    isHnsEnabled: true //needed for sftp
    isSftpEnabled: true //currently in preview
  }
}

resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2021-08-01' = {
  name: 'default'
  parent: sftp
}

resource incoming 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: 'incoming'
  parent: blobServices
}

resource processing 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: 'processing'
  parent: blobServices
}

resource processed 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: 'processed'
  parent: blobServices
}

resource failed 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-08-01' = {
  name: 'failed'
  parent: blobServices
}

resource fred 'Microsoft.Storage/storageAccounts/localUsers@2021-08-01' = {
  name: 'fred'
  parent: sftp
  properties: {
    permissionScopes: [
      {
        permissions: 'rwdlc'
        resourceName: incoming.name
        service: 'blob'
      }
      {
        permissions: 'rwdlc'
        resourceName: processing.name
        service: 'blob'
      }
      {
        permissions: 'rwdlc'
        resourceName: processed.name
        service: 'blob'
      }
      {
        permissions: 'rwdlc'
        resourceName: failed.name
        service: 'blob'
      }
    ]
    hasSshKey: true
    hasSshPassword: false
    sshAuthorizedKeys: [
      {
        description: 'Generate in sub-folder ./keys with name fred'
        key: loadTextContent('./keys/fred.pub', 'utf-8')
      }
    ]
  }
}

resource logaw 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: '${uniqueName}-logaw'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

module logicApp './logic-app.bicep' = {
  name: 'logicApp'
  params: {
    lawid: logaw.id
    uniqueName: uniqueName
    location: location
    sshUsername: fred.name
  }
}

