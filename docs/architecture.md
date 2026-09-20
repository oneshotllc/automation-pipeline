# Automation Architecture — catalog & wiring plan

Status: DESIGN (pre-build). Cleanup of the old home-rolled Python queue is done;
this documents the target pattern before the Redis rebuild.

## Goal

An automation pipeline, owned by NodeMation (n8n), that picks up GitHub work
(issues + PRs), runs it through the Claude subscription shim, and publishes the
result back to GitHub. Separate from Hermes. Cloud-portable (container, queue,
stateless workers).

## End-to-end flow

1. GitHub (app `oneshot-pr-bot`, 27 events) -> POST webhook
   `https://<funnel-host>:10000/webhooks/github`
2. Tailscale funnel `:10000` -> local n8n webhook (RE-POINT from deleted Caddy)
3. n8n "Triage Intake" webhook -> enqueue normalized item to Redis (LPUSH)
4. Redis: durable queue + atomic `SETNX owner/repo#number` dedup
5. Consumer worker -> BRPOP queue -> SETNX claim -> Claude shim -> TDD/BDD spec
   -> publish comment via n8n GitHub node (`ghAppOneshotPr01`)
6. Poller (5 min) -> list all `oneshotllc` open issues+PRs -> LPUSH each (backup
   fetch; same queue + same SETNX dedups against the webhook)

## Catalog

### Exists (retained, untouched)
- n8n native launchd `com.oneshot.n8n`, port 5678, `~/n8n-app/`
- 4 workflows: triage `d59YY3F06IEMKLWh`, poller `kQmdg9QLRiQq2CFz`,
  PR-feedback `21FtNFI7kOtGcLUQ`, pipeline-2 `ghIssuePlanStage2`
- GitHub App `oneshot-pr-bot` (27 events, webhook -> funnel), credential `ghAppOneshotPr01`
- Tailscale funnel `https://<funnel-host>:10000`
- Claude shim `127.0.0.1:8790` + `CLAUDE_CODE_OAUTH_TOKEN`
- This repo (exported workflow definitions)

### Needs wiring (Phase 2)
1. Redis — the queue + SETNX dedup (install; deployment shape TBD)
2. Funnel re-point — `:10000` -> n8n webhook (currently points at deleted Caddy `:8765`)
3. Triage re-wire:
   - claim `POST /internal/delivery/claim` -> Redis `SETNX owner/repo#number`
   - publish `POST /internal/result` -> n8n GitHub node comment
4. Poller re-wire — inject -> Redis LPUSH (was `POST 127.0.0.1:5678/webhook/github-issue-triage`)
5. Consumer worker — Redis BRPOP -> Claude -> publish
6. PR-feedback re-wire — still references `127.0.0.1:8776/internal/*` + filters
   on old `oneshotmn/oneshotmn` (re-point to `oneshotllc/*`)

## Open decision

Deployment shape for Redis:
- A) Native Redis (Homebrew + launchd) next to native n8n — minimal, no n8n migration
- B) Docker Compose (n8n + Redis) — the "container + queue + stateless" shape,
  but requires migrating the live n8n (data, credentials, webhook URL)

## Acceptance (how we test it)

Publish a real GitHub issue; within one poller cycle (<= 5 min) the triage should
claim it once (SETNX), run Claude, and post a TDD/BDD comment. Verify: exactly one
comment, no double-processing, survives a webhook miss (poller catch).
