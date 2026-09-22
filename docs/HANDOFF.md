# HANDOFF — Org backlog triage + NodeMation builder slice

**Written:** 2026-09-19 · **For:** the next agent picking this up · **Owner/approver:** Brian (`bwoestman` on GitHub)
**Status (updated 2026-09-19, later session):** POSTED. Epic = `oneshotllc/.github#27`; C1–C9 = #28 #29 #30 #31 #32 #33 #34 #35 #37 (native blocked-by links + `Next:` lines); `oneshot.help` 530 = #36. All on `hold`, assigned `bwoestman`, authored by `oneshot-pr-bot`. #18/#24/#25/#19 cross-commented. `automation-pipeline` PR #1 has reviewer+assignee. Poller `kQmdg9QLRiQq2CFz` deactivated (C1 re-enables it). §6 below is the text as posted; the live issues are now the source of truth.

---

## 0. Progress log (appended by the executing session, 2026-09-19)

- **C1 #28 CLOSED.** n8n backup `~/n8n-backups/20260919T191353Z-pre-C1/` (integrity ok, queue + claim keys dumped). `triage:queue` deleted; keys renamed to `queue:intake` / `seen:*`. Funnel :10000 now targets Caddy `127.0.0.1:8460` which passes only `/webhook/*` (public `GET /` → 404). `onError=continueRegularOutput` removed from the three GitHub nodes; failures are error executions. Poller re-enabled.
- **C2 #29 CLOSED.** Sorter workflow `EuMYAIadQbkYh0FH` drains intake every minute, drops seen items, routes via `oneshotllc/.github` `automation/streams.json` to `queue:oneshotllc`. Consumer reads the stream queue only and rejects items without `stream`. Queue-depth sampler: launchd `com.oneshot.queue-depth` → `~/.hermes/logs/queue-depth.csv`; 24 h report auto-posts to #29 via `com.oneshot.queue-depth-report`.
- **C3 #30 CLOSED.** Consumer applies `hold` after every spec and sets `spec:{key}`; sorter approval path pushes un-held spec'd issues to `queue:build:oneshotllc` once (`build:{key}` INCR, counts sweeps). Check: `checks/c3-hold-gate.sh` (RED then GREEN on template-smoke). Incident: 34 pre-gate issues briefly entered the build queue; they are now all labeled `hold` and the queue was cleared. No build consumer exists yet, nothing ran.
- **C4 #31 CLOSED.** Webhook `d59YY3F06IEMKLWh` verifies `X-Hub-Signature-256` (secret in loopback Redis `cfg:gh_webhook_secret` and `~/.config/oneshot-pr/webhook-secret`; rotated via the App API), 401 on mismatch, parses real GitHub payloads; bot actors admitted only for opened/reopened. `NODE_FUNCTION_ALLOW_BUILTIN=crypto` added to `~/n8n-app/.env`. Runner: `~/actions-runner-oneshotllc`, registered on `oneshotllc/.github`, label `oneshot-mac`, online; runners 2/3 deleted. 14 local remotes, SOUL.md, memory notes repointed. Pipeline 2 (`ghIssuePlanStage2`) deactivated (dead since the rename). One PR opened: `nextjs-site-template#1` (reusable-workflow `uses:` line). Measured: webhook ingress 30 s, spec 226 s; poller backstop 261 s.
- **C5 #32:** PR #1 merged 2026-09-20 03:37Z after Brian's approval; C5 closes once `automation-pipeline#5` (compose + fresh exports) merges so `master` equals live. C6–C9 remain on `hold`.
- **C5.5 #40 (2026-09-20):** Brian ruled no launchd/cron for pipeline work. NodeMation now runs as the `nodemation` Docker Compose stack under colima (`automation-pipeline/deploy/`, PR #5): n8n 2.35.7, Redis, webhook gate, socat loopback bridge. Host n8n/Redis agents disabled. Boot: the single approved cron line `@reboot ~/bin/nodemation-boot`. Sampler + 24 h report are n8n workflows (`queueDepthSampler1`, `queueDepthReport01`) writing Redis list `metrics:queue-depth`. The Mac had rebooted at 15:52 CT on 09-19 and the pipeline was down ~6.5 h until this session restarted it.
- **Abstraction rebuild (2026-09-20):** Brian rejected PR #8 (ticket refs in workflows). Everything now reads `automation/pipeline.json` (org `.github`) via Redis `cfg:pipeline`, synced by the Config Loader workflow `7D0ysmSWfBZnKZbq`. Rule in memory `workflows-are-abstract-config-holds-the-names`. `checks/no-literals.sh` must pass before any PR. Replacement PR `automation-pipeline#9`. Merger handles human approvals (event + sweep) and Dependabot by policy; redeliverer retries dropped Funnel deliveries (ids kept as strings: they exceed 2^53).
- **C6 #33 CLOSED, C7 #34 CLOSED (2026-09-20):** head-of-chain rule in the sorter (dependencies API + body fallback, `checks/c6-chain-order.sh` PASS); build stage = `build.yml` in org `.github` (config-free, 10 inputs) dispatched by n8n `Build Dispatcher` `3zS0ikpHmlLbf3Um`; proof `template-smoke#18` → PR #19 (46 tests green). **C8 #35 in progress:** merge stage live (event + sweep, Dependabot policy), feedback mode + shipped label built; needs a real approver review on a pipeline PR for the last proof. Chain tickets #35, #37 remain; `automation-pipeline#9` holds all exports.
- **C8.1 #46 CLOSED (2026-09-20 18:5x):** failing counted checks on a pipeline PR become repair builds (event via check_run/workflow_run, sweep backup in the merger, per-PR attempt cap, cross-repo → issue rule in build.yml repair mode). Proof on template-smoke#19: planted failure f063b00 → repair commit 21bbe549 → check green, one attempt. `automation-pipeline#10` merged by event. Config gained `ci.checks`, `repair.*`, `labels.spec_present`, `build.skip_repos`. Open: #47 (retire `enable` job; blocks PR #19 merge/shipped proof) on hold; #48 priority ordering parked with Brian; C8 #35 and C9 #37 close after #47.
- **Rules learned today:** ticket with Gherkin before any work (memory `ticket-with-scenarios-before-any-work`); full URLs, never bare ticket numbers; PR body standard (memory `pr-body-standard`).
- **Branch protection (2026-09-20 ~21:00Z):** applied to all 14 active repos by `deploy/ensure-branch-protection.sh` (PR `automation-pipeline#11`). Every default-branch change is now a PR needing Brian's approval, including `automation/pipeline.json`. #47 closed as redundant; the five `automerge.yml` deletions are PRs under C9 (#37): template-smoke#21, commonboard#19, pr-agent#17, typescript-template#8, agent-pipeline-template#11. After template-smoke#21 merges, an empty commit refreshes PR #19 → merge by event → `shipped` on #18 → close C8 #35, C9 #37, #24, epic #27.
- **Tooling facts:** `n8n import:workflow` fails here (isolated-vm); build via MCP `update_workflow`, export via CLI. Caddy has `admin off`; apply config with `launchctl kickstart -k gui/$UID/com.oneshot.hermes-caddy`.

## 1. Read this first

- **The org is `oneshotllc`** (renamed from `oneshotmn` on 2026-09-19). `api.github.com/orgs/oneshotmn` → 404. Anything still saying `oneshotmn` is stale: `~/.hermes/SOUL.md`, the memory note `oneshot-org-structure.md`, runner registration, local git remotes, reusable-workflow `uses:` lines.
- **Brian's intent:** GitHub Projects/boards are only for the agents. He dispatches work from chat; later, customer requests will be intaked into the issue system. Tickets go in `oneshotllc/.github`.
- **He has approved proceeding** ("I am going to leave you to it"). Nothing is needed from him to start: GitHub access is the bot (§3). His part is approving: removing `hold` on issues and approving PRs.
- **Ticket style rule** (memory `tickets-short-and-bulleted`): one screen, bullets, decision first, cite sources. The bodies in §6 already follow it; do not expand them.
- **PR rule** (memory `request-brians-review-on-every-pr`): every PR gets `bwoestman` as reviewer and assignee at open time. This was not followed on `automation-pipeline` PR #1 — fix it.

## 2. What exists today (verified 2026-09-19)

| Thing | State | Where |
|---|---|---|
| Tracking ticket / epic | Drafted, never posted | §6 of this file (only other copy: session transcript `~/.claude/projects/-Users-oneshot-agent/d76b2c50-3afc-406a-ab87-538aa20aaede.jsonl` line 279) |
| GitHub Project board | None created; deliberately deferred until C6 | — |
| `oneshotllc/.github` issues | Open: #18 router, #19 LangGraph, #24 Dependabot, #25 hold gate. Closed: #1–17, #20–23 (bot provisioning failures + duplicates) | GitHub |
| `oneshotllc/automation-pipeline` | Public repo. PR #1 (`redis-queue-rewire`) open, 0 checks, no reviewer/assignee. `master` has 3 of 6 workflow exports; `redis-triage-consumer.json` missing from master | `~/code/oneshotllc-automation` (branch `redis-queue-rewire`, 3 commits) |
| Local ticket bodies | `approval-gate.md` (=#25), `dependabot-auto-merge.md` (=#24) | `~/code/oneshotllc-automation/tickets/` (duplicates in `~/code/automation-pipeline/tickets/`, delete at C5) |
| Architecture doc | "DESIGN (pre-build)", 6-item Phase-2 wiring list, open Redis decision | `~/code/oneshotllc-automation/docs/architecture.md` |
| Other parked plans | Org repo standard (PROPOSED); Cloudflare hardening ticket plan (PROPOSED); Cloudflare audit (written) | `~/code/.hermes/plans/2026-09-12_org-repo-standard.md`, `2026-09-19_cloudflare-ticket-plan.md`, `~/.hermes/plans/2026-09-19_cloudflare-security-audit.md` |
| VOP port audit | **FILED** as `oneshotllc/voicesofpower#59` (22 items) on 2026-09-19; companion `#58` (missing sections, swapped backgrounds) also filed; local branch `fix/base44-discrepancies` has 1 unpushed commit for #58 | `~/code/voicesofpower/audit-ticket.md` = body of #59 |
| Cloudflare hardening | **FILED** as `oneshotllc/.github#26` (`hold`, `plan-proposed`) | body = `~/.hermes/plans/2026-09-19_cloudflare-security-audit.md` |

## 3. Blockers — what stopped the last two sessions

1. **CORRECTED 2026-09-19 (later session): `gh` was never the path and no login is needed.** GitHub access from this machine is `~/bin/oneshot-pr exec <command>`, which mints a one-hour token for the `oneshot-pr-bot` GitHub App (id 4503014, installed on all 17 `oneshotllc` repos, write on issues/PRs/contents/workflows). Use `oneshot-pr exec gh …` for every issue, label, comment, and PR. Bare `gh auth status` says "not logged in" by design. Do not ask Brian to run `gh auth login`. Verify with `oneshot-pr whoami`.
2. **The follow-up session (job `3d9488ff`) ran in a permission mode that denied Bash, Write into git checkouts, and all n8n MCP tools.** If you hit the same, ask Brian for the narrowest scope (per memory `ask-for-the-permission-you-need`), quoting the refusal.

## 4. Live failures on record (from the 2026-09-19 audit; re-verify before acting)

Ordered by urgency.

- **Tailscale Funnel exposes all of n8n publicly.** `macstudio.tailcb79bc.ts.net:10000` proxies `/` → `127.0.0.1:5678` — editor + credential store + an `authentication: none` webhook that spends Claude tokens and writes to GitHub as the bot. Fix is C1 scenario 2.
- **No approval gate.** Reconciliation poller (`kQmdg9QLRiQq2CFz`) lists every open issue **and PR** org-wide every 5 min; Redis Triage Consumer (`8ukVVloMcWl0jMkz`) spec-comments each. 54 items claimed across 9 repos (voicesofpower 13, commonboard 13, agent-pipeline-template 8, template-smoke 6, typescript-template 4, pr-agent 3, hermex-voice 3, oneshot-help 2, .github 2). This is the "issue flood". Fix is C3.
- **Redis `triage:queue` runaway:** ~3,500–3,900 items, +~600/hr, `maxmemory 0`, throughput ~0 because everything popped is already claimed. Fix is C1 scenario 1.
- **Errors hidden by design:** `Publish Spec Comment` and both poller list nodes are `onError: continueRegularOutput`. 1,534 of 7,413 executions were errors (burst = `ECONNREFUSED 127.0.0.1:8766`, the deleted SQLite queue). Fix is C1 scenario 3.
- **Webhook ingress cannot work:** `POST /webhook/github-issue-triage` (workflow `d59YY3F06IEMKLWh`) parses the poller's internal envelope, not a GitHub payload → normalizes to `owner:"" repo:"" number:0`. Fix is C4.
- **PR Feedback Repair Loop `21FtNFI7kOtGcLUQ` dead but active:** filters `oneshotmn/oneshotmn` (never matches now), POSTs to `127.0.0.1:8776` (not running). Do NOT unpublish; re-wire at C8.
- **Runners:** runner 1 last job `reaction-poll` 2026-09-17T22:12Z despite `*/15` cron; runners 2 and 3 plists unloaded since 09-13. Repoint/re-register at C4. (Brian says Actions work; treat as a wiring check.)
- **`oneshot.help` is down:** HTTP 530 / Cloudflare 1016 (origin DNS). Provision Monitor logged `reachable:false` ~4,970 times, alerts nobody. **Own ticket, out of chain; blocks C8 deploy only.**
- **n8n backup stale:** `~/.n8n/database.sqlite` 731 MB; only backup `20260824T064209Z`. Fix is C1.
- **`com.oneshot.hermes-verification-report`** exits 256 with empty error log — uninvestigated.
- **Orphans to archive/delete after C5:** `~/code/automation-pipeline/` (not a git repo), `~/code/oneshot-pipeline` (42 MB Python, never launched), `~/code/n8n-slice1`, `~/code/n8n-graph-checks`, `~/code/headless-pipeline-policy`, `~/code/.worktrees` (107 Hermes `t_*` worktrees, 23 dirty), a `hermes chat --tui` process running 25+ days.

## 5. Execution order for the next agent

1. Run `oneshot-pr whoami`; it must print `oneshot-pr-bot`. Prefix every `gh` call below with `oneshot-pr exec`.
2. Create labels in `oneshotllc/.github`: `epic`, `stream:oneshotllc`, `pr-open`, `shipped` (`bdd`, `hold`, `needs:triage` exist).
3. Post the epic (§6), then C1–C9 as separate issues, each labeled `bdd`, `hold`, `stream:oneshotllc`, assigned `bwoestman`, each "blocked by" the previous one (fall back to a `Next: #N` line in the body if blocked-by is unavailable on the org). Put the child issue numbers into the epic's task list.
4. Comment on #25, #18, #24: "amended by C3 / C4 / C9; closes when that child closes." Comment on #19: parked until the epic closes.
5. On `automation-pipeline` PR #1: add `bwoestman` as reviewer + assignee now (merge itself is C5).
6. Give Brian the epic URL. He removes `hold` on C1 to start. Work head-of-chain only; on failure comment `stage / error / cause`, fix, resume; close each child with evidence.
7. Triage pass (can run in parallel once `gh` reads private repos): classify all ~54 claimed items by evidence; close irrelevant/duplicate/superseded with a one-line reason; bring only ambiguous ones to Brian; report survivor count. Priority workload after the chain works: Voices of Power's 13 items. Commonboard stays parked (poller skip-list, not per-ticket labels).
8. Separate ticket still to file, on `hold`: `oneshot.help` 530. (Cloudflare hardening = `.github#26` and VOP audit = `voicesofpower#59` were already filed on 2026-09-19; the earlier draft of this handoff was wrong about both.)
9. Housekeeping when convenient: update `~/.hermes/SOUL.md` and the memory note `oneshot-org-structure.md` from `oneshotmn` → `oneshotllc`.

Decisions already made by Brian / prior session (do not re-ask): epic lives in `.github`; finish n8n prototype, defer LangGraph; approval = remove `hold`; low-risk Dependabot (patch/minor, green CI) is pre-approved by policy, major bumps wait for Brian; commonboard on hold; every merge otherwise needs approval.

---

## 6. Ticket text — post as written

# [Epic] Builder slice — NodeMation: intake → approve → build → merge

**Repo:** `oneshotllc/.github` · **Labels:** `epic`, `bdd`, `hold`, `stream:oneshotllc` · **Assignee/reviewer:** bwoestman

**Decision.** Finish the current NodeMation prototype as one vertical slice. Single distribution system: everything enters `queue:intake`, a sorter routes to `queue:<stream>`, one stream (`oneshotllc`) exists today. Ordering is a blocked-by chain inside the stream; approval is removing `hold`. Cloud tools and LangGraph (#19) are parked until this slice runs end to end.

**Given** every child below is approved in order
**When** the pipeline consumes them one at a time, stopping at each `hold`
**Then** a Dependabot PR travels intake → triage → build → merge with no human step, and this epic closes.

**Run protocol.** The consuming bot works the head of the chain only. On failure it comments `stage / error / cause`, fixes, resumes. Each child closes with evidence linked in its final comment.

**Chain (each blocked by the one above):**
1. C1 Safe base and queue rename
2. C2 Sorter and routing table
3. C3 Approval gate — amends #25
4. C4 Ingress, reconciliation, repoint — amends #18
5. C5 Merge `automation-pipeline` PR #1
6. C6 Chain ordering (head-of-chain rule)
7. C7 Build stage: issue → PR
8. C8 PR feedback, merge, deploy
9. C9 Dependabot through the full path — amends #24 (the proof)

**Parked, not in chain:** #19 LangGraph; commonboard work; `oneshot.help` 530 (own ticket, blocks deploy only).

---

## C1 · Safe base and queue rename
Labels `bdd`, `hold`, `stream:oneshotllc`. Blocked by: none (head).

- **Given** `triage:queue` holds ~3,900 duplicate items and the newest n8n backup is 2026-08-24
- **When** `~/.n8n/database.sqlite` is copied to `~/n8n-backups/<date>/`, `triage:queue` is deleted, and every workflow key is renamed `triage:queue` → `queue:intake`, `triage:seen:*` → `seen:*`
- **Then** the backup exists and restores in a dry run, the old key is gone, and the poller and webhook push to `queue:intake`

- **Given** the Funnel on `:10000` proxies `/` to n8n
- **When** Caddy fronts it and passes only `/webhook/*`
- **Then** `GET /` from the internet returns 404, and `POST /webhook/github-issue-triage` still reaches n8n

- **Given** `List Open Issues`, `List Open Pull Requests`, `Publish Spec Comment` are `onError: continueRegularOutput`
- **When** that setting is removed
- **Then** a failed GitHub call is recorded as an error execution

**Done when:** all three scenarios pass; evidence = backup path, `redis-cli KEYS 'queue:*'`, curl output, one deliberately failed execution.

## C2 · Sorter and routing table
Blocked by C1.

- **Given** a routing table `.github/automation/streams.yml` with one rule `* → oneshotllc`
- **When** the sorter workflow pops `queue:intake`
- **Then** it checks `seen:{owner}/{repo}#{number}`, drops duplicates, looks up the stream, and pushes to `queue:oneshotllc` with `stream` set in the payload

- **Given** the poller pushes all 55 open items to `queue:intake` every 5 minutes
- **When** 24 hours pass
- **Then** `queue:intake` and `queue:oneshotllc` never exceed the count of unseen items; no growth

- **Given** the consumer reads `queue:oneshotllc` only
- **When** an item lacks `stream`
- **Then** it is rejected with an error, not processed

**Done when:** sorter exported to `automation-pipeline/workflows/`, table committed, 24-hour flat queue graph attached.

## C3 · Approval gate — amends #25
Blocked by C2. Amendment: `hold` gates the **build**, not intake; every ticket still gets a spec.

- **Given** an issue labeled `hold`
- **When** it reaches the consumer
- **Then** triage writes the spec comment and stops; the build stage never starts

- **Given** Brian removes `hold`
- **When** the next sweep runs (≤ 5 min)
- **Then** the issue proceeds to the build stage exactly once

- **Given** an issue with no `hold` and no spec yet
- **When** triage runs
- **Then** it is labeled `hold` after the spec is posted, so nothing builds unapproved

**Done when:** a failing check exists first (hold-labeled issue builds today), then passes; `.github#25` closed by this ticket.

## C4 · Ingress, reconciliation, repoint — amends #18
Blocked by C3.

- **Given** the GitHub App delivers issue events to `/webhook/github-issue-triage`
- **When** a real `issues.opened` payload arrives
- **Then** the webhook verifies `X-Hub-Signature-256`, rejects a bad signature with 401, and normalizes `repository.owner.login / repository.name / issue.number` into `queue:intake`

- **Given** a delivery is missed
- **When** the 5-minute poller runs
- **Then** the item is picked up by the poller and deduped by the sorter (exactly one spec comment)

- **Given** the runner, local remotes, `intake-gate.yml`, `comment-gate.yml`, `21FtNFI7kOtGcLUQ` and MEMORY.md reference `oneshotmn`
- **When** they are repointed to `oneshotllc`, runner 1 re-registered with label `oneshot-mac`, runners 2 and 3 removed
- **Then** `grep -r oneshotmn` across `~/code`, `~/actions-runner-*`, exported workflows returns nothing, and one runner shows Online

**Done when:** a test issue opened in a private repo produces one spec comment within 60 s via webhook; the same with the Funnel briefly off produces one via the poller. `.github#18` closed by this ticket.

## C5 · Merge `automation-pipeline` PR #1
Blocked by C4.

- **Given** `automation-pipeline` is public and PR #1 exports six workflows
- **When** the exports are scanned for secrets, tokens, internal hostnames
- **Then** none are present, or they are redacted before merge

- **Given** the scan is clean and bwoestman is reviewer
- **When** Brian approves
- **Then** the PR is squash-merged and `master` matches the live n8n export byte-for-byte (re-export and diff)

## C6 · Chain ordering
Blocked by C5.

- **Given** issues A → B → C linked with GitHub "blocked by"
- **When** the consumer selects work from `queue:oneshotllc`
- **Then** it builds only an issue with no open blocker (head of chain); B waits until A closes

- **Given** the blocked-by API is unavailable on this org
- **When** the head-of-chain check runs
- **Then** it falls back to a `Next: #N` line in the issue body

- **Given** Brian inserts D between A and B
- **When** he sets D blocked-by A and B blocked-by D
- **Then** the next selection is D, not B

**Done when:** a three-issue test chain builds in order; insertion test passes.

## C7 · Build stage: issue → PR
Blocked by C6. Starting point: salvage `~/code/.worktrees/oneshotmn-t_5151eeea/pipeline-stage3.yml`.

- **Given** an approved head-of-chain issue with a spec
- **When** the consumer dispatches it
- **Then** Claude Code runs on the `oneshot-mac` runner in a fresh worktree, creates branch `issue-<n>`, adds tests, opens a PR that references the issue, labels the issue `pr-open`

- **Given** the build fails
- **When** the runner exits non-zero
- **Then** the issue gets a comment with the log link and stays `approved`; no PR is opened

**Done when:** one real approved issue produces a PR with green CI and tests.

## C8 · PR feedback, merge, deploy
Blocked by C7.

- **Given** a pipeline PR with review comments
- **When** the PR-feedback loop (`21FtNFI7kOtGcLUQ`, re-wired off `:8776`) runs
- **Then** Claude addresses the comments in a new commit on the same branch

- **Given** CI is green and the issue is approved
- **When** the merge stage runs
- **Then** the PR is squash-merged by the bot and the issue is labeled `shipped`

- **Given** the site has a deploy workflow
- **When** merge completes
- **Then** deploy runs and the URL is commented; **if `oneshot.help` still returns 530, this scenario is skipped and the separate ticket blocks it**

## C9 · Dependabot through the full path — amends #24 (the proof)
Blocked by C8. Amendment: no shortcut; full chain, auto-approved when low risk.

- **Given** a `dependabot[bot]` PR bumping a patch or minor version
- **When** triage runs
- **Then** it classifies `dependency / low-risk`, does not label `hold`, and comments a one-line spec (not a full BDD spec)

- **Given** the classification is low-risk
- **When** the build stage runs
- **Then** tests are added or run, the site builds, CI is green, and the merge stage squash-merges it

- **Given** a major bump
- **When** triage runs
- **Then** it is labeled `hold` and waits for Brian

- **Given** CI is pending
- **When** the merge stage runs
- **Then** the PR is re-queued, not merged, not commented again

**Done when:** one real low-risk Dependabot PR merges with zero human actions; `.github#24` closed by this ticket; the epic closes.

---

## 7. Sources

- Audit + drafts: `~/.claude/projects/-Users-oneshot-agent/d76b2c50-3afc-406a-ab87-538aa20aaede.jsonl` (assistant lines 225, 231, 279)
- Historical failure classes: `~/code/issue_mining/PIPELINE_BEHAVIOR_REPORT.md` (old `oneshotmn/oneshotmn`: 359 issues, dominant mode "silent non-signal")
- Workflow exports: `~/code/oneshotllc-automation/workflows/`
- Memory rules: `~/.claude/projects/-Users-oneshot-agent/memory/` (`tickets-short-and-bulleted`, `request-brians-review-on-every-pr`, `ask-for-the-permission-you-need`, `act-as-cto-decide-then-report`)

### 2026-09-20 evening — bug sweep after branch protection went org-wide
- The four `ci/retire-enable-job` PRs (template-smoke#21, pr-agent#17, typescript-template#8, agent-pipeline-template#11) were red on `check`: each repo's shape tests still opened the deleted `automerge.yml`. Fixed on each branch (tests dropped, prose repointed to the pipeline merger; lint/typecheck/test pass locally). The pushes dismissed Brian's approvals (dismiss_stale_reviews) → review re-requested.
- Strict "branch up to date" was on in the classic protection; turned off on every repo (an update commit would itself dismiss the approval). Config: `branch_protection.require_up_to_date=false`; script reads it.
- template-smoke#19 sat `unstable` (approved, `check` green, retired `enable` red). Merger now merges when state ∈ `merge.accept_states` and all `ci.checks` are green (`Head Checks` + `Merge Decision` nodes; live). Config PR .github#49 + export PR automation-pipeline#12.
- build.yml: after a feedback/repair push the bot re-requests review (approval is dismissed by protection on every push).
- oneshot-help: CI called `oneshotmn/.github` reusable → context `ci / check`, never `check`; Dependabot PRs #4/#1 had no runs at all. PR oneshot-help#5 makes a plain `check` job. After merge: comment `@dependabot rebase` on #4 and #1.
- Cruft: 21 merged/contained branches deleted across 8 repos; host dirs archived to `~/code/_archive/*.tar.gz` and removed (oneshot-pipeline, automation-pipeline tickets, n8n-slice1, n8n-graph-checks, headless-pipeline-policy, oneshotmn-dotgithub [stray commit saved as a patch], *-ref clones). Left alone: `~/code/.worktrees` (11 GB, 105 worktrees of local-finance/local-health/oneshotmn — not pipeline work), `~/code/oneshotmn` (owns 4 of those worktrees), hermex-voice#2 (old bot PR, Brian's call).
- agent-pipeline-template still runs its own old `Worker` (`agent-worker.yml`, `build` check) on PRs; it fails on missing secrets and is not counted. Candidate for retirement with the rest of the pre-NodeMation workflows there.
- 23:20Z: template-smoke#19 merged by the bot on the first tick after .github#49 synced; issue 18 closed + `shipped`. C8 (#35) closed with evidence.
- Dependabot ignores `@dependabot rebase` from an App ("only users with push access"). To refresh a stale Dependabot PR the bot closes and reopens it (`pull_request: reopened` runs CI). Known gap: the merger does not do this itself yet; it only matters for PRs opened before a repo had CI.
- Brian approved and the merger merged: typescript-template#8, oneshot-help#5, .github#49, automation-pipeline#12. Still open: template-smoke#21 (needs re-approval), hermex-voice#2 (Brian's call).
- 23:25Z: oneshot-help#4 and #1 merged by policy after close/reopen ran `check`. C9 (#37) closed with evidence; #24 closed as superseded; epic #27 closed (open follow-ups: #48 parked, #43 pending the next pipeline-built PR, pre-pipeline workflows in agent-pipeline-template).
- State of the org at close: open PRs = template-smoke#21 (awaiting Brian's re-approval), hermex-voice#2 (Brian's call). Every default branch protected; strict off; merger accepts unstable with counted checks green.
- Design decision (Brian, 2026-09-20 late): the n8n-decides / Actions-on-local-runner-executes split stays. Tabled for a future revisit he will explain when relevant. No runner-in-container ticket opened.
- hermex-voice paused: PR #2 closed and branch deleted; issues #1/#3 remain on hold. `~/code/.worktrees` cleared (104/105; one dir with locked test data left; 23 dirty diffs saved in `~/code/_archive/worktrees/`).
- 2026-09-21 00:31Z: Brian un-held VOP#59 (22-item audit ticket). Pipeline reacted in 40 s; build ran 21 min then died at `--max-turns 60`; partial work discarded; failure comment promised a retry the sorter never does (INCR claim = once forever). Fixes: .github#51 (build.yml: bounds from config inputs, stream-json progress in the log, partial work → draft PR, honest failure text; config build.max_turns=200/claim_minutes=90/max_attempts=3, keys.build_attempts_prefix) + automation-pipeline#13 (sorter: claim TTL + attempt cap + re-hold at cap; dispatcher passes the four inputs). Sorter/dispatcher saved as DRAFTS in n8n — publish only after .github#51 merges (old build.yml rejects the new inputs). Then `redis-cli DEL build:oneshotllc/voicesofpower#59` so it re-releases.
- Visibility ticket .github#50 (hub pipeline page + run links on tickets) on hold for Brian.
- 01:37Z: VOP#59 rebuilt with the new bounds: 26 min, all 22 items in 23 commits, PR voicesofpower#62 open (not draft), issue `pr-open`. Retry path proven (claim TTL 90 min, attempt 1/3). Streamed log confirmed by Brian as the watch window he wants.
- PR body defect found on #62: Why = first 3 issue lines (heading + local paths); What changed = full commit bodies. Rewrote #62's body by hand; fix in .github PR (Why from spec **Problem** paragraph, headlines only). #43 closes once that merges and the next PR opens clean.
- Fly cleanup (Brian, 2026-09-21): destroyed 9 stale `voicesofpower-pr-*` apps (46,47,48,51,53,56,57,61,62; all merged). Ticket voicesofpower#63 + PR #64 add a `closed` teardown job to preview.yml. Rule going forward: a preview app lives only while its PR is open. `bdd` label created in VOP.
- 2026-09-21: Brian wants the pipeline to work down the backlog by itself. Decided: org Project "Pipeline" (projects/1, renamed from Triage; Status reshaped to Backlog/Ready/Building/In review/Needs you/Done) is the queue; auto-Ready for bugs and <14-day tickets; one per repo, next after merge; Needs you + tagged comment on any stop. Written into .github#48 (on hold) with 7 scenarios.
- Board cleanup 2026-09-21: closed 17 obsolete tickets (auto-merge era, smoke artifacts, resolved-by-C5.5/C9); apt#12 replaces apt#4/5/6/8 (retire pre-pipeline workflows). VOP project #2 closed (all Done; use Pipeline filtered by repo). Pipeline board seeded with all 25 open org issues (hold→Backlog, else Ready), closed items → Done. oneshot.help still 530 (#36 stays).
- Templates: org project template https://github.com/orgs/oneshotllc/projects/3 (Status + Priority in the pipeline shape); issue forms Ticket + Bug replace the OneShotMN-era form (.github PR #53, inherited by every repo); nextjs-site-template flagged is_template. Repo templates already flagged: typescript-template, agent-pipeline-template.
- 2026-09-21 ~03:00Z, "obvious failure missed" (Brian): (1) he un-held .github#50 at 00:49 and #43 at 02:09; `.github` is in build.skip_repos so the sorter ignored them silently → sorter now comments once ("operator builds this"); I acknowledged both and am building #50 by hand. (2) apt#12 (bdd label, scenarios in body) un-held 02:51 → build failed "no spec comment" → .github PR #54 makes the body the spec when it carries scenarios. (3) voicesofpower.org has NO DNS records (Cloudflare zone dora/tate, domain active to 2027) and Fly had no cert → added Fly certs; Brian must add A/AAAA (apex + www) DNS-only in Cloudflare. (4) pr-agent comment-gate.yml fails on every comment (oneshotmn reusable) → pr-agent#18 retirement ticket.
- Priority (Brian): Voices of Power first; automation only when broken. Board priorities set (VOP high/urgent, automation medium, rest low).
- VOP domain is **thevoicesofpower.org** (group decision 2026-09-20; Cloudflare-registered 09-06, zone empty). Fly: production app `thevoicesofpower` created (shared v4 + v6, media_data volume, certs for apex+www awaiting DNS); wrong-domain certs removed from `voicesofpower`, which stays as staging at voicesofpower.fly.dev. Release-gating ticket opened in VOP (hold): main→staging, GitHub Release + `production` environment approval → production; own DB + secrets.
- 2026-09-21 ~04:00Z: Brian corrected me for reporting stale PR states (52/53/54/ap#14/64 were all merged). Redid with fresh reads. Delivered the TVOP website audit + replan (plan https://github.com/oneshotllc/voicesofpower/issues/66, posted as a VOP issue). Frank's written direction doc is NOT on file; requested. No CLOSE/EDIT/CREATE executed yet.

---

This log moved into the repository on 2026-09-21. Plans are GitHub issues or `docs/` files in the repository they concern; nothing is written to a local plans folder.

### 2026-09-22 — rules restated after the PR mess, and what changed
Brian's rules: tickets are fully specified before any work (Decision, Scope, Scenarios, Done when; no open questions); a PR exists for code approval only, never a spec, a hold or a discussion; an unfinished or failed build is restored by the pipeline, never discussed on a PR, and only a ticket that is wrong comes back to a person; events drive every stage and the poller is a full second path, not a check. Changes made: the ingress and the poller call the sorter directly and the sorter calls the consumer and the dispatcher (no one-minute schedules; event to build run measured at 5 s, poller path at 4 min); triage accepts issue tickets only, defined positively; a failed ticket build is released again at once, capped by `build.max_attempts`, skipped while the ticket is on hold, and at the cap the ticket gets a comment, `needs:triage` and the hold; an approved ticket without Decision/Scope/Scenarios/Done when is refused with one comment and the hold; the build changes only what Scope names and returns a question to the ticket instead of guessing; feedback is a changes-requested review only; the repair agent touches only pipeline files. The `.github` and `automation-pipeline` repositories require a PR but no approval, so the pipeline's own fixes merge on their own. Proofs live on template-smoke tickets 22, 24, 26, 27 and PR 23.
