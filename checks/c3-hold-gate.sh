#!/usr/bin/env bash
# C3 hold-gate check (oneshotllc/.github#30). Exit 0 = PASS, 1 = FAIL. Deterministic; no model call.
#
# Given  a fresh issue labeled `hold` in oneshotllc/template-smoke
# When   the pipeline sweeps it
# Then   it gets exactly one spec comment and NO build-queue entry
# When   `hold` is removed
# Then   exactly one build-queue entry appears within 6 minutes (one poller tick + sorter)
set -uo pipefail
REPO=oneshotllc/template-smoke
GH="$HOME/bin/oneshot-pr exec gh"
STREAM=oneshotllc
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
title="C3 hold-gate check $STAMP"
url=$($GH issue create --repo $REPO --title "$title" --label hold --body "Deterministic check for the hold gate. Safe to close. $STAMP" 2>/dev/null | tail -1)
n=${url##*/}; key="$REPO#$n"
echo "issue: $url"
wait_for() { local secs=$1 test=$2; local end=$((SECONDS+secs)); while [ $SECONDS -lt $end ]; do eval "$test" && return 0; sleep 15; done; return 1; }
in_build_queue() { redis-cli --raw LRANGE "queue:build:$STREAM" 0 -1 | grep -q "\"issue_number\":$n,"; }
build_claim() { redis-cli --raw EXISTS "build:$key"; }
spec_count() { $GH api "repos/$REPO/issues/$n/comments" --jq '[.[]|select(.body|contains("TDD/BDD Execution Spec"))]|length' 2>/dev/null || echo 0; }
# Phase 1: spec must arrive; hold must keep it out of the build queue
if ! wait_for 480 '[ "$(spec_count)" -ge 1 ]'; then echo "FAIL: no spec comment within 8 min"; exit 1; fi
echo "spec comments: $(spec_count)"
sleep 90
if in_build_queue || [ "$(build_claim)" = "1" ]; then echo "FAIL: hold-labeled issue entered the build path"; exit 1; fi
echo "hold respected: no build entry"
# Phase 2: remove hold => exactly one build entry
$GH issue edit $n --repo $REPO --remove-label hold >/dev/null
if ! wait_for 420 '[ "$(build_claim)" = "1" ]'; then echo "FAIL: build claim never appeared after hold removed"; exit 1; fi
sleep 330   # one more poller tick: must not enqueue a second time
c=$(redis-cli --raw GET "build:$key")
q=$(redis-cli --raw LRANGE "queue:build:$STREAM" 0 -1 | grep -c "\"issue_number\":$n,")
echo "build claim counter: $c ; entries in queue:build:$STREAM: $q"
# build:{key} counts sweeps since approval (INCR per poller tick); the push is gated on the first one, so the queue entry count is the "exactly once".
[ "${c:-0}" -ge 1 ] && [ "$q" -eq 1 ] && { echo "PASS"; exit 0; }
echo "FAIL: proceeded more than once"; exit 1
