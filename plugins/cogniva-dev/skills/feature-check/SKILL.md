---
name: feature-check
description: Provide workflow-neutral preflight, review, and commit-readiness evidence for a bounded implementation. Delegates authority discovery and mechanical gates; it never owns lifecycle mutations.
---

# Feature Check

Use this for externally orchestrated bounded implementation, or as a
workflow-neutral review layer around a Claude-managed lifecycle. It accepts:

- `<phase>` — `preflight`, `review`, or `commit-ready`.
- `<repo>` — the target repository root.
- `<target-path>` — one or more intended or changed paths.
- `<purpose>` — a short description of the requested substantive behavior.

## Preflight

Delegate to `applicable-rules` before implementation. Read its reported
authority files, name the intended owner/layer, and stop on a placement or
dependency conflict. A prompt-suggested path is never enough to override a
repository rule.

## Review

Delegate to `applicable-rules`, then inspect the bounded diff against its
reported rules. Confirm that substantive behavior is in the identified owner,
that Host changes are wiring only, and that no new dependency edge bypasses the
repository's permitted direction. Report unresolved design departures for
human judgment rather than disguising them as follow-up work.

## Commit-ready

Run the review phase, then delegate mechanical validation to `gate-check`.
Report which repository-configured validation has passing evidence, what was
skipped, and what remains. `commit-ready` is a readiness report only: it does
not stage, commit, integrate, push, clean, or mutate plans, backlogs, or ADRs.

The caller chooses whether the workflow is Claude-managed or externally
managed. This skill checks shared engineering obligations without taking over
that choice.
