@description('Azure region for the Log Analytics workspace.')
param location string

@description('Base name used to derive the globally-unique Log Analytics workspace name.')
param logAnalyticsBaseName string = 'log-proseware-dev'

var logAnalyticsWorkspaceName = take('${logAnalyticsBaseName}-${uniqueString(resourceGroup().id)}', 63)

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    workspaceCapping: {
      dailyQuotaGb: json('0.5')
    }
  }
}

output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
