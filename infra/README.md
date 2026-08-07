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

Grab the outputs the data ingestion pipeline needs (see root `README.md`) with:

```
az deployment sub show --name main --query "properties.outputs.{compute:computeClusterName.value, identity:ingestIdentityClientId.value}"
```

### Troubleshooting: `RoleAssignmentExists` on deploy

If the deployment fails with `RoleAssignmentExists` and quotes a role assignment ID you don't recognize, it means an assignment for that exact (principal, role, scope) triple already exists under a *different* name than what Bicep computes today — typically left over from an earlier version of a `guid(...)` formula in one of the `infra/*.bicep` files. Retrying the deployment as-is won't fix this, since Bicep will keep computing the same (mismatched) name every time. Diagnose and fix:

```
# 1. find what's actually assigned at the resource in question
az role assignment list --scope <resource-id> --query "[].{name:name, role:roleDefinitionName, principalId:principalId}" -o table

# 2. confirm what today's Bicep wants to create instead, without applying anything
az deployment sub what-if --location eastus2 --template-file infra/main.bicep \
  --parameters secretsOfficerPrincipalId=$(az ad signed-in-user show --query id -o tsv)

# 3. delete the stale assignment, then redeploy
az role assignment delete --ids <full-resource-id-of-the-stale-assignment>
```

This is safe: the principal/role/scope being granted doesn't change, so the redeploy immediately recreates an equivalent assignment under the correct name — there's no meaningful access gap.

### Note: Azure ML workspaces don't support soft-delete purge/list via CLI

Unlike Key Vault (below), the `az ml` extension has no `list-deleted` or `recover` command, and the `Microsoft.MachineLearningServices/deletedWorkspaces` resource type isn't available in this subscription — listing/recovering a soft-deleted workspace is Azure Portal-only ("Recently deleted" view). The CLI only supports the permanent-delete side, via `az ml workspace delete --permanently-delete`, which maps to the SDK's `ml_client.workspaces.begin_delete(permanently_delete=True)`. If you ever hit a workspace name conflict from a soft-deleted workspace, purge it with that command (you need to already know its name — there's no CLI listing), then redeploy.

## Smoke tests

After deploying, `infra/smoke-tests/` has scripts that confirm access to the deployed resources works end-to-end:

```
infra/smoke-tests/smoke-test-storage.sh
infra/smoke-tests/smoke-test-keyvault.sh
infra/smoke-tests/smoke-test-loganalytics.sh
infra/smoke-tests/smoke-test-appinsights.sh
infra/smoke-tests/smoke-test-mlworkspace.sh
infra/smoke-tests/smoke-test-compute-instance.sh
infra/smoke-tests/smoke-test-compute-cluster.sh
```

All read the resource group from `$RESOURCE_GROUP` (defaults to `rg-proseware-dev`) and clean up after themselves. The Log Analytics one is read-only (no diagnostic settings are wired up yet), so it just confirms the workspace exists and its query endpoint responds. The Application Insights one is also read-only — it confirms the resource is provisioned and linked to the Log Analytics workspace. The ML workspace one is also read-only — it confirms the workspace is provisioned, has a system-assigned identity, is linked to the storage account/key vault/App Insights/container registry, and that the identity has role assignments on those resources. The compute instance and compute cluster ones are also read-only — they confirm the compute resources are provisioned with the expected cost-minimizing settings (idle shutdown, SSH disabled, scale-to-zero). Note these two use `az ml compute` (the `ml` extension) rather than `az resource list`, since nested Azure ML compute child resources aren't returned by the generic resource list API.

## Tearing down (stop being charged)

Everything currently deployed here (Storage Account, Key Vault, Log Analytics workspace, Application Insights, Container Registry, Azure ML workspace, compute instance, compute cluster) is pay-as-you-go, so idle cost is low but not zero — it grows once compute-backed resources (the compute instance/cluster now deployed, or the Azure ML online endpoint from ADR 0005) land. When you're done for the day, delete the whole resource group rather than trying to pause individual resources:

Key Vault names in this repo are deterministic (derived from the resource group id, see `infra/keyvault.bicep`), and Key Vault has soft-delete enabled — so deleting the resource group alone leaves the vault name reserved in a soft-deleted state for 7 days. Redeploying before then will fail with a naming conflict. Always purge it as part of teardown:

```
KEYVAULT_NAME=$(az keyvault list --resource-group rg-proseware-dev --query "[0].name" -o tsv)
az group delete --name rg-proseware-dev --yes
az keyvault purge --name "$KEYVAULT_NAME" --location eastus2
```

This deletes every resource in the group and immediately frees the vault name. Notes:
- Purging is destructive — any secrets stored in the vault are gone for good. There's no way to recover them; if you need them again, you'll re-add them after the next deploy.
- Recreate everything later with the same `az deployment sub create` command from [Deploying](#deploying) above — it's idempotent since the resource group name and region are fixed, and will produce the same Key Vault name.
- If you only want to pause future work without deleting anything (e.g. mid-week), there's nothing to "stop" yet — none of the current resources bill for idle compute. This section will matter most once the AML online endpoint (ADR 0005) is deployed, since managed online endpoints bill for their allocated instances whether or not they're serving traffic.
