targetScope = 'subscription'

@description('Name of the resource group to create.')
param resourceGroupName string = 'rg-proseware-dev'

@description('Azure region for the resource group.')
param location string = 'eastus2'

@description('Object ID of the user/service principal to grant Key Vault secret get/set access. Obtain via `az ad signed-in-user show --query id -o tsv`.')
param secretsOfficerPrincipalId string

@description('Whether to deploy the ML workspace compute instance. Set to false to stand up the workspace without incurring compute-instance run time.')
param deployComputeInstance bool = true

resource rg 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: resourceGroupName
  location: location
}

module storage 'storage.bicep' = {
  name: 'storageDeployment'
  scope: rg
  params: {
    location: location
    dataReaderPrincipalId: secretsOfficerPrincipalId
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

module acr 'acr.bicep' = {
  name: 'acrDeployment'
  scope: rg
  params: {
    location: location
  }
}

module mlWorkspace 'mlworkspace.bicep' = {
  name: 'mlWorkspaceDeployment'
  scope: rg
  params: {
    location: location
    storageAccountName: storage.outputs.storageAccountName
    keyVaultName: keyVault.outputs.keyVaultName
    appInsightsId: appInsights.outputs.appInsightsId
    containerRegistryName: acr.outputs.acrName
    deployComputeInstance: deployComputeInstance
  }
}

output computeClusterName string = mlWorkspace.outputs.computeClusterName
output ingestIdentityClientId string = mlWorkspace.outputs.ingestIdentityClientId
output ingestIdentityResourceId string = mlWorkspace.outputs.ingestIdentityResourceId
