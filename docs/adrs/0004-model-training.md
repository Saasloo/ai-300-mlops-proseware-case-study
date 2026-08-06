# ADR 0004 — Model Training

**Status:** Accepted
**Date:** 2026-08-06

---

## Context

Data is landed in Azure Blob Storage (ADR 0002) and moved via Azure Synapse Analytics (ADR 0003). A platform is now needed to train models on top of that data. The team requires a full audit trail of training runs, full control over the training environment and code, and support for Python notebooks as the primary development interface.

## Decision

Use Azure Machine Learning as the platform for training models, using its experiment tracking, job history, and notebook-based compute instances.

## Consequences

**Good:**
- Built-in experiment tracking and job/run history give the full audit trail the team requires.
- Notebook-based compute instances and custom environments give the team full control over code, dependencies, and the training process.
- Native integration with Azure Blob Storage and the rest of the Azure ecosystem established in ADR 0001–0003.
- Aligns with AI-300 exam scope, reinforcing certification prep alongside the practical build.

**Bad / trade-offs:**
- More setup and management overhead than a managed AutoML or no-code training service.
- Team is responsible for managing compute costs, environment/dependency drift, and notebook hygiene since training is not fully abstracted away.

## Open Questions

**Why `Dedicated` VM priority on the training compute cluster (`infra/mlworkspace.bicep`), not `LowPriority`?**

`LowPriority` (pre-emptible/spot-style pricing) is cheaper and was the initial choice, since `scaleSettings.minNodeCount: 0` already means the cluster costs nothing while idle. Deploying it failed with `ClusterMinNodesExceedCoreQuota`: the subscription's `TotalLowPriorityCores` Azure ML quota is `0/0` (a separate quota class from regular vCPU quota, unrelated to the `standardDSv2Family` quota which does have headroom). Rather than block on filing a quota increase request, the cluster uses `Dedicated` priority instead — still scales to zero nodes when idle, so cost stays low, just without the additional spot discount. Revisit if `TotalLowPriorityCores` quota is ever granted for this subscription/region.
