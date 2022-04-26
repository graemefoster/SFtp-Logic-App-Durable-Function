targetScope = 'resourceGroup'

param uniqueName string
param sshUsername string
param location string = resourceGroup().location
param lawid string

//https://docs.microsoft.com/en-us/azure/storage/blobs/secure-file-transfer-protocol-host-keys
var fingerprint = 's8NdoxI0mdWchKMMt/oYtnlFNAD8RUDa1a4lO8aPMpQ='

resource logicPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: '${uniqueName}-logicapp-plan'
  location: location
  sku: {
    tier: 'WorkflowStandard'
    name: 'WS1'
  }
  properties: {
    targetWorkerCount: 1
    maximumElasticWorkerCount: 3
    elasticScaleEnabled: true
    isSpot: false
    zoneRedundant: true
  }
}

resource appi 'Microsoft.Insights/components@2020-02-02' = {
  name: '${uniqueName}-appi'
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

//Where to find the logic app definitions in storage:
var websiteContentShare = 'app-${toLower(uniqueName)}-logicservice'

resource storage 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: '${uniqueName}logicstg'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_GRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }

  resource files 'fileServices@2021-08-01' = {
    name: 'default'

    resource logicAppContent 'shares' = {
      name: websiteContentShare
    }
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
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'node'
        }
        {
          name: 'WEBSITE_NODE_DEFAULT_VERSION'
          value: '~12'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${listKeys(storage.id, '2019-06-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: websiteContentShare
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__id'
          value: 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          name: 'AzureFunctionsJobHost__extensionBundle__version'
          value: '[1.*, 2.0.0)'
        }
        {
          name: 'APP_KIND'
          value: 'workflowApp'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appi.properties.InstrumentationKey
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~2'
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
          value: 'test3hd4msftp.blob.core.windows.net'
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
          value: 'test3hd4msftp.incoming.fred'
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
          value: 'test3hd4msftp.blob.core.windows.net'
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
          value: 'test3hd4msftp.processing.fred'
        }
      ]
      use32BitWorkerProcess: true
    }
    serverFarmId: logicPlan.id
    clientAffinityEnabled: false
  }

  // resource sftpconnection 'workflowsconfiguration@2020-12-01' = {
  //   name: 'connections'
  //   properties: {
  //     files: {
  //       'connections.json': json(loadTextContent('../connections.json'))
  //     }
  //   }
  // }

  // resource workflows 'workflows@2020-12-01' = {
  //   name: 'bicep-test'
  //   properties: {
  //     files: {
  //       'workflow.json': json(loadTextContent('../SftpTrigger/workflow.json'))
  //     }
  //   }
  // }
}

// Return the Logic App service name and farm name
output app string = site.name
output plan string = logicPlan.name
