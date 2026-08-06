# ADR 0005 — Model Deployment

**Status:** Proposed
**Date:** 2026-08-06

---

## Context

Models are trained on Azure Machine Learning (ADR 0004). Per `docs/requirements.md`, doctors enter patient info and tap Analyze expecting a prediction immediately, during consultations that run under 10 minutes. Predictions are individual and on-demand — one patient at a time, not batch — so the serving layer must respond synchronously with low latency rather than on a schedule or queue.

## Decision

Deploy the trained model to an Azure Machine Learning managed online endpoint: an always-on, low-latency real-time inference endpoint that serves one prediction per request over a synchronous HTTP call.

## Consequences

**Good:**
- Always-on compute eliminates cold-start delay, meeting the "immediate prediction" expectation during time-constrained consultations.
- Synchronous request/response model matches the one-patient-at-a-time, on-demand usage pattern — no batching or polling required.
- Native integration with the Azure ML workspace and models from ADR 0004, with built-in versioning, traffic splitting, and monitoring.

**Bad / trade-offs:**
- Always-on compute incurs cost even during idle periods (e.g. overnight, weekends) when no consultations are happening.
- Team takes on responsibility for endpoint scaling, availability, and monitoring instead of a simpler batch/offline scoring pipeline.

## Open Questions

- What instance size and autoscaling rule are appropriate for the expected consultation volume?
