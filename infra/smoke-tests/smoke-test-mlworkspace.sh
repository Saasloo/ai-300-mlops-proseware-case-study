#!/usr/bin/env bash
# Confirms the Azure ML workspace is provisioned, has a system-assigned identity,
# and is linked to its storage account, key vault, App Insights, and container registry.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-proseware-dev}"

WORKSPACE_ID=$(az resource list -g "$RESOURCE_GROUP" \
  --resource-type "Microsoft.MachineLearningServices/workspaces" --query "[0].id" -o tsv)
if [[ -z "$WORKSPACE_ID" ]]; then
  echo "No Azure ML workspace found in resource group $RESOURCE_GROUP" >&2
  exit 1
fi
echo "Using ML workspace: $(basename "$WORKSPACE_ID")"

WORKSPACE_INFO=$(az resource show --ids "$WORKSPACE_ID" \
  --query "{state: properties.provisioningState, identityType: identity.type, principalId: identity.principalId, storage: properties.storageAccount, keyVault: properties.keyVault, appInsights: properties.applicationInsights, acr: properties.containerRegistry}" \
  -o json)
PROVISIONING_STATE=$(echo "$WORKSPACE_INFO" | jq -r '.state')
IDENTITY_TYPE=$(echo "$WORKSPACE_INFO" | jq -r '.identityType')
PRINCIPAL_ID=$(echo "$WORKSPACE_INFO" | jq -r '.principalId')

if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
  echo "FAIL: ML workspace provisioning state is '$PROVISIONING_STATE', expected 'Succeeded'" >&2
  exit 1
fi

if [[ "$IDENTITY_TYPE" != "SystemAssigned" ]]; then
  echo "FAIL: ML workspace identity type is '$IDENTITY_TYPE', expected 'SystemAssigned'" >&2
  exit 1
fi

if [[ -z "$PRINCIPAL_ID" || "$PRINCIPAL_ID" == "null" ]]; then
  echo "FAIL: ML workspace has no system-assigned identity principal ID" >&2
  exit 1
fi

for field in storage keyVault appInsights acr; do
  VALUE=$(echo "$WORKSPACE_INFO" | jq -r ".$field")
  if [[ -z "$VALUE" || "$VALUE" == "null" ]]; then
    echo "FAIL: ML workspace is missing its '$field' link" >&2
    exit 1
  fi
done

STORAGE_ID=$(echo "$WORKSPACE_INFO" | jq -r '.storage')
KEYVAULT_ID=$(echo "$WORKSPACE_INFO" | jq -r '.keyVault')
ACR_ID=$(echo "$WORKSPACE_INFO" | jq -r '.acr')

for resource_id in "$STORAGE_ID" "$KEYVAULT_ID" "$ACR_ID"; do
  ROLE_COUNT=$(az role assignment list --assignee "$PRINCIPAL_ID" --scope "$resource_id" --query "length(@)" -o tsv)
  if [[ "$ROLE_COUNT" -lt 1 ]]; then
    echo "FAIL: workspace identity has no role assignment on $resource_id" >&2
    exit 1
  fi
done

echo "PASS: ML workspace is provisioned with a system-assigned identity linked to storage, key vault, App Insights, and ACR ($(basename "$WORKSPACE_ID"))"
