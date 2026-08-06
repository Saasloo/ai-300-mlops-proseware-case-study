@description('Azure region for the storage account.')
param location string

@description('Base name used to derive the globally-unique storage account name.')
param storageAccountBaseName string = 'stprosewaredev'

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
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

output storageAccountName string = storageAccount.name
