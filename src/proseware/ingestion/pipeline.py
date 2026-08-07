"""Submit the Kaggle data ingestion script (kaggle.py) as an Azure ML job.

Runs kaggle.py on the training compute cluster (infra/mlworkspace.bicep) instead
of a developer's laptop, under the dedicated ingestion managed identity so the
job can call back into the workspace control plane (check/register data assets)
without interactive login. See docs/architecture.md and ADR 0002/0004.
"""

import argparse
import logging
import os
from pathlib import Path

from azure.ai.ml import MLClient, command
from azure.ai.ml.entities import BuildContext, Environment, ManagedIdentityConfiguration
from azure.identity import DefaultAzureCredential, InteractiveBrowserCredential
from dotenv import load_dotenv

from proseware.ingestion.kaggle import DEFAULT_ASSET_NAME, DEFAULT_DATASET

INGEST_SCRIPT_DIR = Path(__file__).parent
ENVIRONMENT_NAME = "kaggle-ingest-env"
ENVIRONMENT_VERSION = "2"  # bumped: switched from a conda-based env to a Dockerfile built with uv

logger = logging.getLogger(__name__)


def get_dev_credential():
    credential = DefaultAzureCredential()
    try:
        credential.get_token("https://management.azure.com/.default")
    except Exception:
        credential = InteractiveBrowserCredential()
    return credential


def get_or_create_environment(ml_client: MLClient) -> Environment:
    environment = Environment(
        name=ENVIRONMENT_NAME,
        version=ENVIRONMENT_VERSION,
        build=BuildContext(path=str(INGEST_SCRIPT_DIR)),
    )
    return ml_client.environments.create_or_update(environment)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default=DEFAULT_DATASET, help="Kaggle dataset handle (owner/dataset-slug)")
    parser.add_argument("--asset-name", default=DEFAULT_ASSET_NAME, help="Azure ML data asset name")
    parser.add_argument(
        "--compute-name",
        default=os.environ.get("AML_COMPUTE_NAME"),
        help="Name of the training compute cluster to run on "
        "(infra/main.bicep output computeClusterName, or $AML_COMPUTE_NAME)",
    )
    parser.add_argument(
        "--identity-client-id",
        default=os.environ.get("AML_INGEST_IDENTITY_CLIENT_ID"),
        help="Client ID of the ingestion managed identity the job runs under "
        "(infra/main.bicep output ingestIdentityClientId, or $AML_INGEST_IDENTITY_CLIENT_ID)",
    )
    parser.add_argument(
        "--config-path",
        default=None,
        help="Path to the Azure ML workspace config.json (defaults to MLClient.from_config's own lookup)",
    )
    parser.add_argument("--log-level", default="INFO", help="Logging level (e.g. DEBUG, INFO, WARNING)")
    args = parser.parse_args()
    logging.basicConfig(level=args.log_level, format="%(asctime)s %(levelname)s %(message)s")

    if not args.compute_name:
        parser.error("--compute-name is required (or set $AML_COMPUTE_NAME)")
    if not args.identity_client_id:
        parser.error("--identity-client-id is required (or set $AML_INGEST_IDENTITY_CLIENT_ID)")

    load_dotenv()
    kaggle_username = os.environ.get("KAGGLE_USERNAME")
    kaggle_key = os.environ.get("KAGGLE_KEY")
    if not kaggle_username or not kaggle_key:
        parser.error("KAGGLE_USERNAME and KAGGLE_KEY must be set (see .env.example)")

    credential = get_dev_credential()
    ml_client = MLClient.from_config(credential=credential, path=args.config_path)

    logger.info("Ensuring ingestion environment %s:%s exists ...", ENVIRONMENT_NAME, ENVIRONMENT_VERSION)
    environment = get_or_create_environment(ml_client)

    job = command(
        display_name="kaggle-diabetes-ingest",
        experiment_name="data-ingestion",
        code=str(INGEST_SCRIPT_DIR),
        command=f"python kaggle.py --dataset '{args.dataset}' --asset-name '{args.asset_name}'",
        environment=f"{environment.name}:{environment.version}",
        compute=args.compute_name,
        identity=ManagedIdentityConfiguration(client_id=args.identity_client_id),
        environment_variables={
            "KAGGLE_USERNAME": kaggle_username,
            "KAGGLE_KEY": kaggle_key,
            "AZURE_CLIENT_ID": args.identity_client_id,
        },
    )

    returned_job = ml_client.jobs.create_or_update(job)
    logger.info("Submitted job %s -> %s", returned_job.name, returned_job.studio_url)


if __name__ == "__main__":
    main()
