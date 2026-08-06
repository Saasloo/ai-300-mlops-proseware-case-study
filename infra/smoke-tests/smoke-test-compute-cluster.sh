#!/usr/bin/env bash
# Confirms the training compute cluster is provisioned with scale-to-zero settings.
# Note: nested Azure ML compute resources aren't returned by `az resource list`,
# so this uses the `az ml compute` commands (requires the `ml` extension) instead.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-proseware-dev}"

WORKSPACE_NAME=$(az resource list -g "$RESOURCE_GROUP" \
  --resource-type "Microsoft.MachineLearningServices/workspaces" --query "[0].name" -o tsv)
if [[ -z "$WORKSPACE_NAME" ]]; then
  echo "No Azure ML workspace found in resource group $RESOURCE_GROUP" >&2
  exit 1
fi

COMPUTE_NAME=$(az ml compute list -g "$RESOURCE_GROUP" -w "$WORKSPACE_NAME" \
  --query "[?type=='amlcompute'] | [0].name" -o tsv)
if [[ -z "$COMPUTE_NAME" ]]; then
  echo "No compute cluster found in workspace $WORKSPACE_NAME" >&2
  exit 1
fi
echo "Using compute cluster: $COMPUTE_NAME"

COMPUTE_INFO=$(az ml compute show -g "$RESOURCE_GROUP" -w "$WORKSPACE_NAME" -n "$COMPUTE_NAME" \
  --query "{state: provisioning_state, minNodeCount: min_instances, maxNodeCount: max_instances, idleScaleDown: idle_time_before_scale_down}" \
  -o json)
PROVISIONING_STATE=$(echo "$COMPUTE_INFO" | jq -r '.state')
MIN_NODE_COUNT=$(echo "$COMPUTE_INFO" | jq -r '.minNodeCount')
MAX_NODE_COUNT=$(echo "$COMPUTE_INFO" | jq -r '.maxNodeCount')

if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
  echo "FAIL: compute cluster provisioning state is '$PROVISIONING_STATE', expected 'Succeeded'" >&2
  exit 1
fi

if [[ "$MIN_NODE_COUNT" != "0" ]]; then
  echo "FAIL: compute cluster min node count is '$MIN_NODE_COUNT', expected '0' (scale to zero when idle)" >&2
  exit 1
fi

if [[ "$MAX_NODE_COUNT" != "2" ]]; then
  echo "FAIL: compute cluster max node count is '$MAX_NODE_COUNT', expected '2'" >&2
  exit 1
fi

echo "PASS: compute cluster is provisioned, scale $MIN_NODE_COUNT-$MAX_NODE_COUNT nodes ($COMPUTE_NAME)"
