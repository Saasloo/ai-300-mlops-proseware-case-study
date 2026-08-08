@description('Azure region for the container registry.')
param location string

@description('Base name used to derive the globally-unique container registry name.')
param acrBaseName string = 'acrprosewaredev'

var acrName = take('${acrBaseName}${uniqueString(resourceGroup().id)}', 50)

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    // Identity-based ACR pulls (managed identity + AcrPull) for AmlCompute proved unreliable
    // in practice - AggregatedUnauthorizedAccessError persisted even with correct RBAC on a
    // freshly-provisioned resource group. Falling back to the admin user, which AML uses
    // automatically via Key Vault-stored credentials.
    adminUserEnabled: true
  }
}

output acrName string = acr.name
output acrId string = acr.id
