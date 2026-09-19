# oneshotllc-automation

NodeMation (n8n) workflow definitions for the OneShot LLC automation pipeline.
This repo is the version-controlled source of the automation — separate from
Hermes and separate from the (removed) Python queue.

## Workflows

| Workflow | n8n ID | File | Notes |
|---|---|---|---|
| GitHub Issue TDD BDD Triage | `d59YY3F06IEMKLWh` | `workflows/github-issue-tdd-bdd-triage.json` | Webhook ingest → item-key claim → Claude TDD/BDD spec → publish |
| GitHub Issue Reconciliation Poller | `kQmdg9QLRiQq2CFz` | `workflows/github-issue-reconciliation-poller.json` | Every 5 min: list all `oneshotllc` repos' open issues+PRs → normalize → re-inject |
| GitHub PR Feedback Repair Loop | `21FtNFI7kOtGcLUQ` | `workflows/github-pr-feedback-repair-loop.json` | PR lifecycle webhook → bounded/durable dispatch |
| Pipeline 2: ready → implementation plan | `ghIssuePlanStage2` | *(not MCP-exportable)* | Lives only in n8n; enable MCP access to export |

## Migration notes (Phase 2 — Redis rebuild)

The triage workflow still references the old home-rolled Python queue via two
HTTP calls that are now dead (the queue was removed):

- `Claim Delivery Before Model` → `POST http://127.0.0.1:8766/internal/delivery/claim`
  (atomic item-key claim, `owner/repo#number`)
- `Publish Managed Spec` → `POST http://127.0.0.1:8766/internal/result`
  (GitHub comment publish)

Phase 2 replaces both with a Redis-backed queue:
- claim → Redis `SETNX <owner/repo#number>`
- publish → n8n GitHub node (the `ghAppOneshotPr01` credential)

The PR-feedback workflow references `http://127.0.0.1:8776/internal/*` (also removed)
and still filters on the old `oneshotmn/oneshotmn` repo — needs re-pointing to `oneshotllc/*`.

## Credentials (in n8n, not this repo)

- `ghAppOneshotPr01` — GitHub App "oneshot-pr-bot" (`githubAppApi`)
- `hAALzdx6tjvYAQG6` — Claude (subscription via shim) (`anthropicApi`)

## Org

`oneshotllc` (renamed from `oneshotmn` 2026-09-19).
