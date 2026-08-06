#!/usr/bin/env bash
# Round-trips a test blob through the deployed storage account to confirm access works.
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rg-proseware-dev}"
CONTAINER_NAME="smoke-test"
BLOB_NAME="smoke-test-$(date +%s).txt"
LOCAL_FILE=$(mktemp)
DOWNLOAD_FILE=$(mktemp)
trap 'rm -f "$LOCAL_FILE" "$DOWNLOAD_FILE"' EXIT

echo "smoke test $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOCAL_FILE"

STORAGE_ACCOUNT=$(az storage account list -g "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [[ -z "$STORAGE_ACCOUNT" ]]; then
  echo "No storage account found in resource group $RESOURCE_GROUP" >&2
  exit 1
fi
echo "Using storage account: $STORAGE_ACCOUNT"

ACCOUNT_KEY=$(az storage account keys list -g "$RESOURCE_GROUP" -n "$STORAGE_ACCOUNT" --query "[0].value" -o tsv)

az storage container create \
  --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" \
  --name "$CONTAINER_NAME" --output none

az storage blob upload \
  --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" \
  --container-name "$CONTAINER_NAME" --name "$BLOB_NAME" --file "$LOCAL_FILE" \
  --overwrite --output none

az storage blob download \
  --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" \
  --container-name "$CONTAINER_NAME" --name "$BLOB_NAME" --file "$DOWNLOAD_FILE" \
  --output none

az storage blob delete \
  --account-name "$STORAGE_ACCOUNT" --account-key "$ACCOUNT_KEY" \
  --container-name "$CONTAINER_NAME" --name "$BLOB_NAME" --output none

if diff -q "$LOCAL_FILE" "$DOWNLOAD_FILE" > /dev/null; then
  echo "PASS: storage account round trip succeeded ($STORAGE_ACCOUNT)"
else
  echo "FAIL: downloaded blob content does not match what was uploaded" >&2
  exit 1
fi
