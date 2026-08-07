# ai-300-mlops-proseware-case-study

## Data ingestion

`ingest-kaggle-dataset` downloads a Kaggle dataset and registers it as an Azure ML data asset, landing the raw CSV in the workspace's Blob Storage datastore (see ADR 0002).

Prerequisites:
- Kaggle API credentials: set `KAGGLE_USERNAME` and `KAGGLE_KEY` in `.env` (see `.env.example`), generated from https://www.kaggle.com/settings.
- `az login` completed and `experiments/config.json` present, pointing at the deployed Azure ML workspace (same file the training notebook uses).

Run it locally with:

```
uv run ingest-kaggle-dataset
```

By default this lands `rahibvk/real-diabetes-lab-results-and-biomarkers-anti-pima` as the `diabetes-lab-results-raw` data asset. Pass `--dataset`, `--asset-name`, `--asset-version`, or `--description` to override. Re-running with unchanged source data is a no-op — the asset version defaults to a content hash of the CSV, and the script skips registration if that version already exists.

### Running as an Azure ML job

For anything beyond ad-hoc local runs, `submit-ingest-job` submits `ingest.py` as a job on the training compute cluster instead of running it on a laptop, under a dedicated managed identity (`infra/mlworkspace.bicep`) with `AzureML Data Scientist` access so it can check/register data assets on its own.

Prerequisites (in addition to the ones above):
- `infra/main.bicep` deployed with the updated `infra/mlworkspace.bicep` (adds the `ingestIdentity` managed identity + role assignment).
- The compute cluster name and ingestion identity client ID from the deployment outputs:
  ```
  az deployment sub show --name <deployment-name> --query "properties.outputs.{compute:computeClusterName.value, identity:ingestIdentityClientId.value}"
  ```

Run it with:

```
uv run submit-ingest-job --compute-name <computeClusterName> --identity-client-id <ingestIdentityClientId>
```

or export `AML_COMPUTE_NAME` / `AML_INGEST_IDENTITY_CLIENT_ID` to skip passing them each time. This has no schedule yet — it's submit-on-demand only.