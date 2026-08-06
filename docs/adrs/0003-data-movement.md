# ADR 0003 — Data Movement

**Status:** Accepted
**Date:** 2026-08-06

---

## Context

Data lands in Azure Blob Storage (ADR 0002) but needs to be moved and transformed to feed downstream training and MLOps pipelines. A service is needed to orchestrate and execute that movement natively within the Azure ecosystem already established (ADR 0001).

## Decision

Use Azure Synapse Analytics to move data out of Azure Blob Storage into the pipelines and stores that consume it for training.

## Consequences

**Good:**
- Native integration with Azure Blob Storage and Azure ML, avoiding third-party ETL/orchestration tools.
- Combines data integration (pipelines/data flows) and analytics/querying in one service, reducing the number of moving parts.
- Aligns with AI-300 exam scope, reinforcing certification prep alongside the practical build.

**Bad / trade-offs:**
- Adds another Azure service to provision, secure, and monitor beyond storage and compute.
- Synapse has a steeper learning curve and higher idle cost than simpler options (e.g. Azure Data Factory alone) if usage stays lightweight.
