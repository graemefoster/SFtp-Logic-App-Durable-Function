targetScope = 'resourceGroup'

param uniqueName string
param sftpName string
param sshUsername string
param location string = resourceGroup().location
param lawid string

resource logicPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${uniqueName}-durable-function-plan'
  location: location
  sku: {
    name : 'S1'
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: '${uniqueName}-durable-appi'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    Flow_Type: 'Bluefield'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    Request_Source: 'rest'
    RetentionInDays: 30
    WorkspaceResourceId: lawid
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${uniqueName}funcstg'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}

// App service containing the workflow runtime
resource site 'Microsoft.Web/sites@2021-02-01' = {
  name: '${uniqueName}-logicapp'
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appi.properties.ConnectionString
        }
        {
          name: 'Sftp_password'
          value: ''
        }
        {
          name: 'Sftp_portNumber'
          value: '22'
        }
        {
          name: 'Sftp_rootDirectory'
          value: '/'
        }
        {
          name: 'Sftp_sshHostAddress'
          value: '${sftpName}.blob.core.windows.net'
        }
        {
          name: 'Sftp_sshHostKeyFingerprint'
          value: 'BE:8A:4D:A4:19:4D:6C:FA:DA:98:8C:D8:D9:25:8C:5F'
        }
        {
          name: 'Sftp_sshPrivateKey'
          value: loadTextContent('./keys/fred', 'utf-8') //todo - put into keyvault and read via keyvault reference
        }
        {
          name: 'Sftp_sshPrivateKeyPassphrase'
          value: ''
        }
        {
          name: 'Sftp_username'
          value: '${sftpName}.incoming.${sshUsername}'
        }
        {
          name: 'Sftp_12_password'
          value: ''
        }
        {
          name: 'Sftp_12_portNumber'
          value: '22'
        }
        {
          name: 'Sftp_12_rootDirectory'
          value: '/'
        }
        {
          name: 'Sftp_12_sshHostAddress'
          value: '${sftpName}.blob.core.windows.net'
        }
        {
          name: 'Sftp_12_sshHostKeyFingerprint'
          value: 'BE:8A:4D:A4:19:4D:6C:FA:DA:98:8C:D8:D9:25:8C:5F'
        }
        {
          name: 'Sftp_12_sshPrivateKey'
          value: loadTextContent('./keys/fred', 'utf-8') //todo - put into keyvault and read via keyvault reference
        }
        {
          name: 'Sftp_12_sshPrivateKeyPassphrase'
          value: ''
        }
        {
          name: 'Sftp_12_username'
          value: '${sftpName}.processing.${sshUsername}'
        }
      ]
      use32BitWorkerProcess: true
    }
    serverFarmId: logicPlan.id
    clientAffinityEnabled: false
  }

}

// Return the Logic App service name and farm name
output app string = site.name
output plan string = logicPlan.name
