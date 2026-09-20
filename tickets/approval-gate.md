## Where this is built

**n8n (NodeMation)** — the `GitHub Issue Reconciliation Poller` workflow (id `kQmdg9QLRiQq2CFz`) in the n8n instance running on this Mac via launchd `com.oneshot.n8n` (port 5678). This automation lives in n8n, NOT in Hermes. Hermes only writes this ticket; the n8n pipeline executes it.

---

## Approval gate: pause tickets until owner approves

### Problem
The poller lists every open issue+PR across all `oneshotllc` repos and enqueues them, and the consumer spec-comments them immediately. There is no "wait for approval" state — a ticket created in chat gets picked up and worked before Brian has approved it.

### Goal
A `hold` label gate: tickets are created with `hold`, the pipeline skips them, and removing `hold` is the approval that releases the ticket into the queue.

### Design
In `GitHub Issue Reconciliation Poller` (id `kQmdg9QLRiQq2CFz`), filter the open issue/PR lists to EXCLUDE items whose labels contain `hold`. A label removal (the approval) lets the next poll (≤5 min) pick it up.

### Acceptance
- An issue/PR with `hold` is never enqueued.
- Removing `hold` causes the item to be enqueued on the next poll and worked end-to-end.
- No other behavior changes.

### Out of scope
Consumer Dependabot branch (#20), Tailscale funnel, app webhook URL, credentials.
