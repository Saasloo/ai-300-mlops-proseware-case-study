"""Land a Kaggle dataset in Azure Blob Storage and register it as an Azure ML data asset.

Downloads a Kaggle dataset locally via kagglehub, then uses the Azure ML SDK to
upload the raw CSV into the workspace's default Blob Storage datastore
(ADR 0002) and register it as a versioned data asset, replacing the manual
upload the MS Learn lab relied on.
"""

import argparse
import hashlib
import logging
import os
from pathlib import Path

import kagglehub
import pandas as pd
from azure.ai.ml import MLClient
from azure.ai.ml.constants import AssetTypes
from azure.ai.ml.entities import Data
from azure.identity import (
    DefaultAzureCredential,
    InteractiveBrowserCredential,
    ManagedIdentityCredential,
)
from azure.core.exceptions import ResourceNotFoundError

DEFAULT_DATASET = "rahibvk/real-diabetes-lab-results-and-biomarkers-anti-pima"
DEFAULT_ASSET_NAME = "diabetes-lab-results-raw"

logger = logging.getLogger(__name__)


def get_credential():
    managed_identity_client_id = os.environ.get("AZURE_CLIENT_ID")
    if managed_identity_client_id:
        # Running as an AML job under the ingestion managed identity (infra/mlworkspace.bicep) -
        # no interactive fallback available on unattended compute.
        return ManagedIdentityCredential(client_id=managed_identity_client_id)

    credential = DefaultAzureCredential()
    try:
        credential.get_token("https://management.azure.com/.default")
    except Exception:
        credential = InteractiveBrowserCredential()
    return credential


def get_ml_client(credential, config_path: str | None) -> MLClient:
    # AML jobs auto-inject these env vars identifying the workspace they're running in.
    subscription_id = os.environ.get("AZUREML_ARM_SUBSCRIPTION")
    resource_group = os.environ.get("AZUREML_ARM_RESOURCEGROUP")
    workspace_name = os.environ.get("AZUREML_ARM_WORKSPACE_NAME")
    if subscription_id and resource_group and workspace_name:
        return MLClient(
            credential=credential,
            subscription_id=subscription_id,
            resource_group_name=resource_group,
            workspace_name=workspace_name,
        )
    return MLClient.from_config(credential=credential, path=config_path)


def download_dataset(dataset: str) -> Path:
    return Path(kagglehub.dataset_download(dataset))


def find_csv(download_dir: Path) -> Path:
    csv_files = sorted(download_dir.rglob("*.csv"))
    if not csv_files:
        raise FileNotFoundError(f"No CSV file found under {download_dir}")
    return csv_files[0]


def compute_content_hash(csv_path: Path) -> str:
    digest = hashlib.sha256()
    with csv_path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()[:12]


def validate_csv(csv_path: Path) -> None:
    df = pd.read_csv(csv_path)
    if df.empty:
        raise ValueError(f"{csv_path} has no rows")
    fully_null_columns = [c for c in df.columns if df[c].isna().all()]
    if fully_null_columns:
        raise ValueError(f"{csv_path} has fully-null columns: {fully_null_columns}")
    logger.info("Validated %s: %d rows, %d columns", csv_path, *df.shape)


def data_asset_exists(ml_client: MLClient, name: str, version: str) -> bool:
    try:
        ml_client.data.get(name=name, version=version)
        return True
    except ResourceNotFoundError:
        return False


def register_data_asset(
    ml_client: MLClient,
    csv_path: Path,
    name: str,
    version: str,
    description: str,
) -> Data:
    data_asset = Data(
        path=str(csv_path),
        type=AssetTypes.URI_FILE,
        name=name,
        version=version,
        description=description,
    )
    return ml_client.data.create_or_update(data_asset)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dataset", default=DEFAULT_DATASET, help="Kaggle dataset handle (owner/dataset-slug)")
    parser.add_argument("--asset-name", default=DEFAULT_ASSET_NAME, help="Azure ML data asset name")
    parser.add_argument(
        "--asset-version",
        default=None,
        help="Azure ML data asset version (defaults to a hash of the CSV's content, "
        "so identical content is a no-op and changed content gets a new version)",
    )
    parser.add_argument(
        "--description",
        default=None,
        help="Azure ML data asset description (defaults to a message naming the source Kaggle dataset)",
    )
    parser.add_argument(
        "--config-path",
        default=None,
        help="Path to the Azure ML workspace config.json (defaults to MLClient.from_config's own lookup)",
    )
    parser.add_argument(
        "--log-level",
        default="INFO",
        help="Logging level (e.g. DEBUG, INFO, WARNING)",
    )
    args = parser.parse_args()
    logging.basicConfig(level=args.log_level, format="%(asctime)s %(levelname)s %(message)s")

    logger.info("Downloading Kaggle dataset %s ...", args.dataset)
    download_dir = download_dataset(args.dataset)
    csv_path = find_csv(download_dir)
    logger.info("Found %s", csv_path)

    validate_csv(csv_path)

    version = args.asset_version or compute_content_hash(csv_path)

    credential = get_credential()
    ml_client = get_ml_client(credential, args.config_path)

    if data_asset_exists(ml_client, args.asset_name, version):
        logger.info(
            "Data asset %s:%s already registered with this content, skipping upload",
            args.asset_name,
            version,
        )
        return

    description = args.description or f"Raw CSV landed from Kaggle dataset {args.dataset}"
    data_asset = register_data_asset(
        ml_client, csv_path, args.asset_name, version, description
    )
    logger.info("Registered data asset %s:%s -> %s", data_asset.name, data_asset.version, data_asset.path)


if __name__ == "__main__":
    main()
