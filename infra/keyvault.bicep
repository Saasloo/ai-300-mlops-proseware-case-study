@description('Azure region for the key vault.')
param location string

@description('Base name used to derive the globally-unique key vault name.')
param keyVaultBaseName string = 'kv-proseware-dev'

@description('Object ID of the user/service principal to grant get/set secret access (Key Vault Secrets Officer). Pass the identity that needs to read/write secrets, e.g. via `az ad signed-in-user show --query id -o tsv`.')
param secretsOfficerPrincipalId string

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

@description('Grants the specified principal Key Vault Secrets Officer (get/set/list/delete secrets).')
resource secretsOfficerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, secretsOfficerPrincipalId, 'KeyVaultSecretsOfficer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalId: secretsOfficerPrincipalId
  }
}

output keyVaultName string = keyVault.name
