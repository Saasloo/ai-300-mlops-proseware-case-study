# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A design-and-build case study for the Microsoft AI-300 (Designing and Implementing an AI Solution) certification. It implements an end-to-end MLOps solution for a healthcare scenario: doctors enter patient data (pregnancies, age, BMI, ...) during a consultation and expect an immediate prediction. The repo is being built incrementally, step by step, following the architecture already decided in `docs/adrs/` — expect infra, pipeline, and training/serving code to land in stages rather than all at once. Don't assume a stage is out of scope just because its code doesn't exist yet; check `docs/adrs/` and `docs/architecture.md` for what's planned.

## Structure

- `docs/architecture.md` — the end-to-end data flow diagram (Mermaid) tying the ADRs together: Patient DB → Synapse → Blob Storage → Azure ML → real-time endpoint.
- `docs/requirements.md` — source of truth for constraints (team is Python/notebook-first, latency requirements, on-demand single-patient predictions, privacy-sensitive data).
- `docs/adrs/000N-*.md` — Architecture Decision Records, numbered sequentially. Each decision builds on prior ones (cloud provider → storage → data movement → training → deployment). Use `docs/adrs/template.md` when adding a new ADR, and cross-reference the ADR number from `docs/architecture.md` if it changes the data flow.
- `infra/` — Azure infrastructure (Bicep), being built out now. `infra/README.md` has the quick-start (`az login`) and MCP prerequisites. An `azure-bicep` MCP server (Microsoft's `@azure/mcp`) is configured in `.mcp.json` for Bicep schema lookups and Azure resource operations — requires Node ≥22 via `fnm`.

## Key architectural decisions already made (see docs/adrs/)

- **Azure only** (ADR 0001) — sole cloud provider, chosen partly to align with AI-300 exam scope. Don't introduce other cloud providers.
- **Azure Blob Storage** (ADR 0002) — landing zone for all raw/intermediate data.
- **Azure Synapse Analytics** (ADR 0003) — moves/transforms data out of Blob Storage toward training.
- **Azure Machine Learning** (ADR 0004) — training platform, using notebook-based compute instances and built-in experiment tracking.
- **Azure ML managed online endpoint** (ADR 0005, status: Proposed) — always-on, synchronous, single-prediction-per-request serving (not batch). Open question noted in the ADR: instance size / autoscaling rule for expected consultation volume.

When adding new work (infra, pipelines, notebooks), keep it consistent with these decisions, or add a new ADR if you're changing one.

## Working conventions

- ADRs follow `docs/adrs/template.md`'s format: Status, Date, Context, Decision, Consequences (Good / Bad), optional Open Questions.
- `.lsp.json` configures `bicep-ls` for `.bicep`/`.bicepparam` files — expect Bicep IaC under `infra/`.
