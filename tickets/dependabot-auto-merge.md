## Where this is built

**n8n (NodeMation)** — the `Redis Triage Consumer` workflow (id `8ukVVloMcWl0jMkz`) in the n8n instance running on this Mac via launchd `com.oneshot.n8n` (port 5678). This automation lives in n8n, NOT in Hermes. Hermes only writes this ticket; the n8n pipeline executes it.

---

## Dependabot auto-merge in the triage consumer

### Problem
The Redis Triage Consumer writes a TDD/BDD spec comment on every open item it pops, including Dependabot dependency bumps. A version bump ("bump vitest 4.1.11 → 5.0.1") has no problem statement to spec — the spec is waste, and the PR should simply merge once CI is green. Today it posts noise comments on Dependabot PRs.

### Goal
Give the consumer a Dependabot branch: when it pops a `dependabot[bot]` PR it does NOT write a spec — it checks CI, and if green, squash-merges the PR.

### Design
In the consumer workflow `Redis Triage Consumer` (id `8ukVVloMcWl0jMkz`), after `Pop Queue Item`:

- Detect `author == dependabot[bot]` AND the item is a PR.
- Low-risk check: semver patch/minor (title "…from X to Y"; a major bump is not low-risk). If the version can't be parsed reliably, treat as low-risk (fail open) and log the title.
- Low-risk → check the PR's check-runs: `GET /repos/oneshotllc/{repo}/commits/{head_sha}/check-runs` using the app installation token. If all check runs have `conclusion == success` (at least one check) AND the PR is mergeable → merge via the GitHub node (`merge`, squash, credential `ghAppOneshotPr01`).
- Not green / not finished → `RPUSH` the item back to the queue tail WITHOUT claiming (re-check next run).
- Not low-risk (major bump) → do NOT auto-merge; route to the human path (and never post a spec comment on a Dependabot PR).

### Acceptance
- A low-risk Dependabot PR with green CI is squash-merged automatically, with no comment.
- A Dependabot PR with failing or pending CI is re-queued, not merged, not commented.
- A major-bump Dependabot PR is not auto-merged.
- Non-Dependabot items still flow through the existing `INCR` claim → Claude → publish path, unchanged.

### Out of scope
Tailscale funnel, app webhook URL, Redis credential, Claude shim — unchanged.
