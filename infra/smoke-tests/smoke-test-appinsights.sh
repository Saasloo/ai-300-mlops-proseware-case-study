#!/usr/bin/env bash
# Confirms the Application Insights resource is provisioned and linked to a Log Analytics workspace.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-proseware-dev}"

APPINSIGHTS_NAME=$(az monitor app-insights component show -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [[ -z "$APPINSIGHTS_NAME" ]]; then
  echo "No Application Insights resource found in resource group $RESOURCE_GROUP" >&2
  exit 1
fi
echo "Using Application Insights resource: $APPINSIGHTS_NAME"

APPINSIGHTS_INFO=$(az monitor app-insights component show \
  -g "$RESOURCE_GROUP" -a "$APPINSIGHTS_NAME" \
  --query "{state: provisioningState, workspaceId: workspaceResourceId, connectionString: connectionString}" -o json)
PROVISIONING_STATE=$(echo "$APPINSIGHTS_INFO" | jq -r '.state')
WORKSPACE_ID=$(echo "$APPINSIGHTS_INFO" | jq -r '.workspaceId')
CONNECTION_STRING=$(echo "$APPINSIGHTS_INFO" | jq -r '.connectionString')

if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
  echo "FAIL: Application Insights provisioning state is '$PROVISIONING_STATE', expected 'Succeeded'" >&2
  exit 1
fi

if [[ -z "$WORKSPACE_ID" || "$WORKSPACE_ID" == "null" ]]; then
  echo "FAIL: Application Insights is not linked to a Log Analytics workspace" >&2
  exit 1
fi

if [[ -z "$CONNECTION_STRING" || "$CONNECTION_STRING" == "null" ]]; then
  echo "FAIL: Application Insights connection string is missing" >&2
  exit 1
fi

echo "PASS: Application Insights resource is provisioned and linked to Log Analytics workspace ($APPINSIGHTS_NAME)"
