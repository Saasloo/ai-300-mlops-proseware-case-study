# Quick start


1. In the CLI, login to your azure account and select the right subscription
`az login` -> then follow the steps from the CLI

## Azure/Bicep MCP server

This repo has an `azure-bicep` MCP server configured in `.mcp.json` (Microsoft's official `@azure/mcp`), which gives Claude Code tools for Bicep schema lookup and Azure resource operations.

Prerequisites:
- [`fnm`](https://github.com/Node-JS-Version-Manager/fnm) installed, with Node 22 available (`fnm install 22`) — the server requires Node >=22
- `az login` completed (step 1 above)

Claude Code will pick up the server automatically when you open this project (you may be prompted to approve it on first use).

## Deploying

```
az deployment sub create \
  --location eastus2 \
  --template-file infra/main.bicep \
  --parameters secretsOfficerPrincipalId=$(az ad signed-in-user show --query id -o tsv)
```

## Smoke tests

After deploying, `infra/smoke-tests/` has scripts that round-trip a test blob/secret through the deployed resources to confirm access works end-to-end:

```
infra/smoke-tests/smoke-test-storage.sh
infra/smoke-tests/smoke-test-keyvault.sh
```

Both read the resource group from `$RESOURCE_GROUP` (defaults to `rg-proseware-dev`) and clean up after themselves.
