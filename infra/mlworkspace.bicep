@description('Azure region for the machine learning workspace.')
param location string

@description('Base name used to derive the globally-unique machine learning workspace name.')
param workspaceBaseName string = 'mlw-proseware-dev'

@description('Name of the storage account this workspace uses for default datastores.')
param storageAccountName string

@description('Name of the key vault this workspace uses to store secrets and connection credentials.')
param keyVaultName string

@description('Resource ID of the Application Insights instance this workspace sends monitoring data to.')
param appInsightsId string

@description('Name of the container registry this workspace uses for custom training/scoring environment images.')
param containerRegistryName string

@description('Base name used to derive the compute instance name.')
param computeInstanceBaseName string = 'ci-proseware-dev'

@description('VM size for the compute instance. Defaults to the cheapest size generally available for notebook development.')
param computeInstanceVmSize string = 'Standard_DS1_v2'

@description('ISO8601 duration of inactivity after which the compute instance auto-shuts-down. Minimum PT15M, maximum P3D.')
param computeInstanceIdleShutdown string = 'PT30M'

@description('AAD object ID of the user assigned as the personal owner of the compute instance (typically the signed-in developer).')
param computeInstanceOwnerObjectId string

var workspaceName = take('${workspaceBaseName}-${uniqueString(resourceGroup().id)}', 32)
var computeInstanceName = take('${computeInstanceBaseName}-${uniqueString(resourceGroup().id)}', 24)

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: containerRegistryName
}

resource mlWorkspace 'Microsoft.MachineLearningServices/workspaces@2025-06-01' = {
  name: workspaceName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: workspaceName
    storageAccount: storageAccount.id
    keyVault: keyVault.id
    applicationInsights: appInsightsId
    containerRegistry: containerRegistry.id
  }
}

@description('Grants the workspace identity Storage Blob Data Contributor on its storage account.')
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccount.id, mlWorkspace.id, 'StorageBlobDataContributor')
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
    principalId: mlWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grants the workspace identity Key Vault Secrets Officer on its key vault.')
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, mlWorkspace.id, 'KeyVaultSecretsOfficer')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
    principalId: mlWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Grants the workspace identity AcrPull on its container registry.')
resource acrRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.id, mlWorkspace.id, 'AcrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
    principalId: mlWorkspace.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

@description('Personal notebook compute instance for interactive development. Billed hourly while running regardless of usage - stop it when not in use.')
resource computeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2025-06-01' = {
  parent: mlWorkspace
  name: computeInstanceName
  location: location
  properties: {
    computeType: 'ComputeInstance'
    properties: {
      vmSize: computeInstanceVmSize
      applicationSharingPolicy: 'Personal'
      idleTimeBeforeShutdown: computeInstanceIdleShutdown
      sshSettings: {
        sshPublicAccess: 'Disabled'
      }
      personalComputeInstanceSettings: {
        assignedUser: {
          objectId: computeInstanceOwnerObjectId
          tenantId: tenant().tenantId
        }
      }
    }
  }
}

output mlWorkspaceName string = mlWorkspace.name
output mlWorkspaceId string = mlWorkspace.id
output mlWorkspacePrincipalId string = mlWorkspace.identity.principalId
output computeInstanceName string = computeInstance.name
