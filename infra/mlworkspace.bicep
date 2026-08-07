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

@description('Whether to deploy the compute instance. Set to false to stand up the workspace without incurring compute-instance run time.')
param deployComputeInstance bool = true

@description('Base name used to derive the training compute cluster name.')
param computeClusterBaseName string = 'cc-proseware-dev'

@description('VM size for the training compute cluster nodes.')
param computeClusterVmSize string = 'Standard_DS2_v2'

@description('Base name used to derive the managed identity that ingestion jobs run under.')
param ingestIdentityBaseName string = 'id-proseware-ingest-dev'

var workspaceName = take('${workspaceBaseName}-${uniqueString(resourceGroup().id)}', 32)
var computeInstanceName = take('${computeInstanceBaseName}-${uniqueString(resourceGroup().id)}', 24)
var computeClusterName = take('${computeClusterBaseName}-${uniqueString(resourceGroup().id)}', 24)
var ingestIdentityName = take('${ingestIdentityBaseName}-${uniqueString(resourceGroup().id)}', 32)

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
resource computeInstance 'Microsoft.MachineLearningServices/workspaces/computes@2025-06-01' = if (deployComputeInstance) {
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

@description('Training compute cluster. Scales to zero nodes when idle and uses low-priority (pre-emptible) pricing to minimize cost.')
resource computeCluster 'Microsoft.MachineLearningServices/workspaces/computes@2025-06-01' = {
  parent: mlWorkspace
  name: computeClusterName
  location: location
  properties: {
    computeType: 'AmlCompute'
    properties: {
      vmSize: computeClusterVmSize
      vmPriority: 'Dedicated'
      osType: 'Linux'
      remoteLoginPortPublicAccess: 'Disabled'
      scaleSettings: {
        minNodeCount: 0
        maxNodeCount: 2
        nodeIdleTimeBeforeScaleDown: 'PT120S'
      }
    }
  }
}

@description('User-assigned managed identity that ingestion jobs (e.g. the Kaggle data ingestion job) run under, so they can call back into the workspace control plane (register/check data assets) without interactive login.')
resource ingestIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: ingestIdentityName
  location: location
}

@description('Grants the ingestion identity AzureML Data Scientist on the workspace, so ingestion jobs can read/write data assets.')
resource ingestIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(mlWorkspace.id, ingestIdentity.id, 'AzureMLDataScientist')
  scope: mlWorkspace
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'f6c7c914-8db3-469d-8ca1-694a8f32e121')
    principalId: ingestIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output mlWorkspaceName string = mlWorkspace.name
output mlWorkspaceId string = mlWorkspace.id
output mlWorkspacePrincipalId string = mlWorkspace.identity.principalId
output computeInstanceName string = deployComputeInstance ? computeInstance.name : ''
output computeClusterName string = computeCluster.name
output ingestIdentityClientId string = ingestIdentity.properties.clientId
output ingestIdentityResourceId string = ingestIdentity.id
