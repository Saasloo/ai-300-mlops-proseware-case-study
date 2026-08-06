@description('Azure region for the Application Insights resource.')
param location string

@description('Base name used to derive the globally-unique Application Insights resource name.')
param appInsightsBaseName string = 'appi-proseware-dev'

@description('Resource ID of the Log Analytics workspace this Application Insights instance sends data to.')
param logAnalyticsWorkspaceId string

var appInsightsName = take('${appInsightsBaseName}-${uniqueString(resourceGroup().id)}', 63)

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
  }
}

output appInsightsName string = appInsights.name
output appInsightsId string = appInsights.id
output appInsightsConnectionString string = appInsights.properties.ConnectionString
