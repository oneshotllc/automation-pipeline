#!/usr/bin/env bash
# Chain-ordering check. Exit 0 = PASS. Deterministic; no model call beyond the pipeline's own spec step.
# Given three approved, specified issues A -> B -> C linked with blocked_by
# Then only A enters the build queue; after A closes, B does; inserting D between A and B makes D next, not B.
set -uo pipefail
GH="$HOME/bin/oneshot-pr exec gh"
CFG=$(redis-cli --raw GET cfg:pipeline)
cfgv(){ printf '%s' "$CFG" | python3 -c "import json,sys;d=json.load(sys.stdin);print(eval('d'+sys.argv[1]))" "$1"; }
REPO=${SMOKE_REPO:?set SMOKE_REPO=<owner>/<repo>}
STREAM=$(cfgv "['streams']['default']"); HOLD=$(cfgv "['labels']['hold']"); SPEC_PREFIX=$(cfgv "['keys']['spec_prefix']"); SEEN_PREFIX=$(cfgv "['keys']['seen_prefix']")
BUILD_PREFIX=$(cfgv "['keys']['build_prefix']"); BUILDQ=$(cfgv "['queues']['build_prefix']")$STREAM
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
mk(){ $GH issue create --repo "$REPO" --title "chain check $STAMP $1" --body "Chain-ordering check. Safe to close." 2>/dev/null | tail -1 | sed 's#.*/##'; }
A=$(mk A); B=$(mk B); C=$(mk C); echo "issues A=$A B=$B C=$C"
# make them "already specified and approved" without waiting for the model: seen + spec markers, no hold label
for n in $A $B $C; do redis-cli SET "${SEEN_PREFIX}${REPO}#$n" 1 EX 604800 >/dev/null; redis-cli SET "${SPEC_PREFIX}${REPO}#$n" check >/dev/null; $GH issue edit $n --repo "$REPO" --remove-label "$HOLD" >/dev/null 2>&1; done
id(){ $GH api "repos/$REPO/issues/$1" --jq .id; }
link(){ $GH api -X POST "repos/$REPO/issues/$1/dependencies/blocked_by" -F issue_id=$(id $2) >/dev/null; }
unlink(){ $GH api -X DELETE "repos/$REPO/issues/$1/dependencies/blocked_by/$(id $2)" >/dev/null 2>&1; }
link $B $A; link $C $B; echo "linked: $B blocked by $A; $C blocked by $B"
inq(){ redis-cli --raw LRANGE "$BUILDQ" 0 -1 | grep -c "\"issue_number\":$1," ; }
claimed(){ redis-cli --raw EXISTS "${BUILD_PREFIX}${REPO}#$1"; }
wait_for(){ local secs=$1 test=$2; local end=$((SECONDS+secs)); while [ $SECONDS -lt $end ]; do eval "$test" && return 0; sleep 15; done; return 1; }
# Phase 1: only A may enter
wait_for 420 '[ "$(claimed $A)" = "1" ]' || { echo "FAIL: A never entered the build queue"; exit 1; }
sleep 60; [ "$(claimed $B)" = "0" ] && [ "$(claimed $C)" = "0" ] || { echo "FAIL: B or C entered while A is open"; exit 1; }
echo "phase 1 ok: A claimed, B and C waiting"
# Phase 2: insert D between A and B, then close A -> D must be next, not B
D=$(mk D); redis-cli SET "${SEEN_PREFIX}${REPO}#$D" 1 EX 604800 >/dev/null; redis-cli SET "${SPEC_PREFIX}${REPO}#$D" check >/dev/null; $GH issue edit $D --repo "$REPO" --remove-label "$HOLD" >/dev/null 2>&1
link $D $A; unlink $B $A; link $B $D; echo "inserted D=$D: D blocked by A; B blocked by D"
$GH issue close $A --repo "$REPO" --comment "chain check: closing A" >/dev/null
wait_for 420 '[ "$(claimed $D)" = "1" ]' || { echo "FAIL: D never entered after A closed"; exit 1; }
sleep 60; [ "$(claimed $B)" = "0" ] && [ "$(claimed $C)" = "0" ] || { echo "FAIL: B or C entered ahead of D"; exit 1; }
echo "phase 2 ok: D claimed, B and C waiting"
# cleanup
for n in $B $C $D; do $GH issue close $n --repo "$REPO" --comment "chain check: done" >/dev/null; done
for n in $A $B $C $D; do redis-cli DEL "${BUILD_PREFIX}${REPO}#$n" "${SPEC_PREFIX}${REPO}#$n" >/dev/null; done
redis-cli --raw LRANGE "$BUILDQ" 0 -1 | grep -E "\"issue_number\":($A|$B|$C|$D)," | while read -r l; do redis-cli LREM "$BUILDQ" 0 "$l" >/dev/null; done
echo PASS; exit 0
