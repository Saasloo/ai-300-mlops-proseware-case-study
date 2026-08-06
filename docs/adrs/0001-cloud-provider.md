# ADR 0001 — Cloud Provider

**Status:** Accepted
**Date:** 2026-08-06

---

## Context

This case study is being built as part of preparation for the Microsoft AI-300 (Designing and Implementing an AI Solution) certification, which is scoped entirely around Azure AI and MLOps services (Azure Machine Learning, Azure AI Foundry, Azure DevOps/Pipelines, etc.). The project needs a cloud provider chosen up front so that tooling, service naming, and pipeline design are consistent across the repo, rather than left generic or multi-cloud.

## Decision

Use Microsoft Azure as the sole cloud provider for this project, standardizing on Azure Machine Learning and related Azure services for training, deployment, and MLOps workflows.

## Consequences

**Good:**
- Direct alignment with AI-300 exam objectives — the work doubles as hands-on certification prep.
- Access to Azure ML's built-in MLOps tooling (pipelines, model registry, endpoints) without needing to bridge multiple providers.
- Simpler, single-provider IAM, networking, and cost management.

**Bad / trade-offs:**
- Vendor lock-in to Azure-specific services and APIs; patterns won't transfer directly to AWS/GCP equivalents.
- Learning and setup choices are shaped by exam scope rather than by evaluating the best-fit provider for a real production workload.
