@description('Azure region for the storage account.')
param location string

@description('Base name used to derive the globally-unique storage account name.')
param storageAccountBaseName string = 'stprosewaredev'

@description('Object ID of the user/service principal to grant Storage Blob Data Reader access, for notebook code that reads blobs directly (e.g. via azure-identity/fsspec) rather than through the AML datastore credential path.')
param dataReaderPrincipalId string

var storageAccountName = '${storageAccountBaseName}${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: take(storageAccountName, 24)
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    isHnsEnabled: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

@description('Grants the specified principal Storage Blob Data Reader, so it can read blobs directly with its own AAD identity (bypassing the AML datastore credential, e.g. mltable/dataprep version conflicts).')
resource dataReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, dataReaderPrincipalId, 'StorageBlobDataReader')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1')
    principalId: dataReaderPrincipalId
  }
}

output storageAccountName string = storageAccount.name
