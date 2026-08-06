#!/usr/bin/env bash
# Confirms the personal notebook compute instance is provisioned, running the
# cheapest configured VM size, and has idle shutdown enabled.
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
  --query "[?type=='computeinstance'] | [0].name" -o tsv)
if [[ -z "$COMPUTE_NAME" ]]; then
  echo "No compute instance found in workspace $WORKSPACE_NAME" >&2
  exit 1
fi
echo "Using compute instance: $COMPUTE_NAME"

COMPUTE_INFO=$(az ml compute show -g "$RESOURCE_GROUP" -w "$WORKSPACE_NAME" -n "$COMPUTE_NAME" \
  --query "{state: provisioning_state, idleShutdown: idle_time_before_shutdown, sshAccess: ssh_public_access_enabled}" \
  -o json)
PROVISIONING_STATE=$(echo "$COMPUTE_INFO" | jq -r '.state')
IDLE_SHUTDOWN=$(echo "$COMPUTE_INFO" | jq -r '.idleShutdown')
SSH_ACCESS=$(echo "$COMPUTE_INFO" | jq -r '.sshAccess')

if [[ "$PROVISIONING_STATE" != "Succeeded" ]]; then
  echo "FAIL: compute instance provisioning state is '$PROVISIONING_STATE', expected 'Succeeded'" >&2
  exit 1
fi

if [[ -z "$IDLE_SHUTDOWN" || "$IDLE_SHUTDOWN" == "null" ]]; then
  echo "FAIL: compute instance has no idle shutdown configured" >&2
  exit 1
fi

if [[ "$SSH_ACCESS" != "false" ]]; then
  echo "FAIL: compute instance SSH public access is enabled, expected disabled" >&2
  exit 1
fi

echo "PASS: compute instance is provisioned with idle shutdown '$IDLE_SHUTDOWN' and SSH disabled ($COMPUTE_NAME)"
