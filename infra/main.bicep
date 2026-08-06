targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'rg-proseware-dev'

@description('Azure region for the resource group.')
param location string = 'eastus2'

@description('Object ID of the user/service principal to grant Key Vault secret get/set access. Obtain via `az ad signed-in-user show --query id -o tsv`.')
param secretsOfficerPrincipalId string

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
    secretsOfficerPrincipalId: secretsOfficerPrincipalId
  }
}

module logAnalytics 'loganalytics.bicep' = {
  name: 'logAnalyticsDeployment'
  scope: rg
  params: {
    location: location
  }
}

module appInsights 'appinsights.bicep' = {
  name: 'appInsightsDeployment'
  scope: rg
  params: {
    location: location
    logAnalyticsWorkspaceId: logAnalytics.outputs.logAnalyticsWorkspaceId
  }
}
