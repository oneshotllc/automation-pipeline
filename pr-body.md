## Where this is built

**NodeMation (n8n)** — the n8n instance running on this Mac via launchd `com.oneshot.n8n` (port 5678). These workflow definitions are the source of truth for the triage pipeline. **NOT Hermes** — Hermes only plans and writes tickets; the automation lives and runs in n8n.

## What changed

Re-export after the Redis queue rebuild. The home-rolled Python queue (SQLite on `:8766`) was deleted; the triage pipeline now runs on a real Redis queue:

- **`github-issue-tdd-bdd-triage`** (ingress) — webhook → normalize → `LPUSH triage:queue`. Dead `:8766` calls removed.
- **`redis-triage-consumer`** (new) — 1-min schedule → `RPOP` → `INCR` claim (`triage:seen:{owner}/{repo}#{number}`) → Claude shim → GitHub comment.
- **`github-issue-reconciliation-poller`** — 5-min → list open issues/PRs across `oneshotllc` → `LPUSH triage:queue`.
- **`github-pr-feedback-repair-loop`** — unchanged, re-exported.
- **`oneshot-provision-monitor`** — unchanged, re-exported.
- **`pipeline-2-ready-to-implementation`** — unchanged, re-exported (now CLI-exportable).

Plus two planning tickets in `tickets/`: `oneshotllc/.github#20` (Dependabot auto-merge) and `#21` (approval gate).

## Verification

- Redis `:6379` running (`sh.brew.redis`).
- End-to-end proven: poller → Redis → consumer → Claude → GitHub comment (spec comments on `commonboard#11–17`).
- Funnel `:10000` → n8n `:5678`; app webhook URL → `/webhook/github-issue-triage`.
