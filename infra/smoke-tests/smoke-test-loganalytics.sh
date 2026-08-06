#!/usr/bin/env bash
# Confirms the Log Analytics workspace is provisioned and its query endpoint is reachable.
# No diagnostic settings are wired up yet, so there's no log data to round-trip -
# this runs a trivial KQL query that doesn't depend on any table having data.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-proseware-dev}"

WORKSPACE_NAME=$(az monitor log-analytics workspace list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [[ -z "$WORKSPACE_NAME" ]]; then
  echo "No Log Analytics workspace found in resource group $RESOURCE_GROUP" >&2
  exit 1
fi
echo "Using Log Analytics workspace: $WORKSPACE_NAME"

WORKSPACE_INFO=$(az monitor log-analytics workspace show \
  -g "$RESOURCE_GROUP" -n "$WORKSPACE_NAME" --query "{state: provisioningState, id: customerId}" -o json)
PROVISIONING_STATE=$(echo "$WORKSPACE_INFO" | jq -r '.state')
WORKSPACE_ID=$(echo "$WORKSPACE_INFO" | jq -r '.id')

if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
  echo "FAIL: workspace provisioning state is '$PROVISIONING_STATE', expected 'Succeeded'" >&2
  exit 1
fi

RESULT=$(az monitor log-analytics query \
  --workspace "$WORKSPACE_ID" \
  --analytics-query "print ok=1" --query "[0].ok" -o tsv)

if [[ "$RESULT" == "1" ]]; then
  echo "PASS: Log Analytics workspace query endpoint responded ($WORKSPACE_NAME)"
else
  echo "FAIL: unexpected query result '$RESULT'" >&2
  exit 1
fi
