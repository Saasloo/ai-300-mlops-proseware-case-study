@description('Azure region for the key vault.')
param location string

@description('Base name used to derive the globally-unique key vault name.')
param keyVaultBaseName string = 'kv-proseware-dev'

var keyVaultName = take('${keyVaultBaseName}-${uniqueString(resourceGroup().id)}', 24)

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

output keyVaultName string = keyVault.name
