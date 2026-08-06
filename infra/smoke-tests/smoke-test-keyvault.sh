#!/usr/bin/env bash
# Round-trips a test secret through the deployed key vault to confirm data-plane access works.
# Requires the caller to hold a secrets data role (e.g. Key Vault Secrets Officer) on the vault.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-proseware-dev}"
SECRET_NAME="smoke-test-secret"
SECRET_VALUE="smoke-test-$(date +%s)"

KEY_VAULT=$(az keyvault list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [[ -z "$KEY_VAULT" ]]; then
  echo "No key vault found in resource group $RESOURCE_GROUP" >&2
  exit 1
fi
echo "Using key vault: $KEY_VAULT"

az keyvault secret set \
  --vault-name "$KEY_VAULT" --name "$SECRET_NAME" --value "$SECRET_VALUE" --output none

RETRIEVED=$(az keyvault secret show --vault-name "$KEY_VAULT" --name "$SECRET_NAME" --query "value" -o tsv)

az keyvault secret delete --vault-name "$KEY_VAULT" --name "$SECRET_NAME" --output none
az keyvault secret purge --vault-name "$KEY_VAULT" --name "$SECRET_NAME" --output none 2>/dev/null || true

if [[ "$RETRIEVED" == "$SECRET_VALUE" ]]; then
  echo "PASS: key vault secret round trip succeeded ($KEY_VAULT)"
else
  echo "FAIL: retrieved secret value does not match what was set" >&2
  exit 1
fi
