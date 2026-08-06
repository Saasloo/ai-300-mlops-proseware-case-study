targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'rg-proseware-dev'

@description('Azure region for the resource group.')
param location string = 'eastus2'

resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
}

module storage 'storage.bicep' = {
  name: 'storageDeployment'
  scope: rg
  params: {
    location: location
  }
}

module keyVault 'keyvault.bicep' = {
  name: 'keyVaultDeployment'
  scope: rg
  params: {
    location: location
  }
}
