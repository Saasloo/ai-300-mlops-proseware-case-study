# ADR 0002 — Data Storage

**Status:** Accepted
**Date:** 2026-08-06

---

## Context

With Azure chosen as the cloud provider (ADR 0001), the project needs a landing zone for raw and intermediate data used in training and MLOps workflows. The storage choice should be native to Azure, cost-effective for large unstructured/semi-structured datasets, and integrate directly with Azure ML and downstream data movement tooling.

## Decision

Use Azure Blob Storage as the landing location for all data ingested into the project — the source data lands here before any processing or movement to other services.

## Consequences

**Good:**
- Native integration with Azure ML datastores and Azure Synapse (see ADR 0003) with no extra connectors.
- Low-cost, scalable object storage well suited to raw files, datasets, and model artifacts.
- Supports hierarchical namespace (ADLS Gen2) if structured data lake organization is needed later.

**Bad / trade-offs:**
- Not a queryable store on its own — any analytics or transformation requires a separate compute/query layer (e.g. Synapse) on top.
- Access control and lifecycle management (retention, tiering) need to be explicitly configured rather than assumed.
