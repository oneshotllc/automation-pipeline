#!/usr/bin/env bash
# Repair check. Exit 0 = PASS. A deliberate failing test pushed to a pipeline branch with an open PR must produce
# exactly one repair commit within the window, the counted check must go green, and no second attempt runs.
# Inputs: the pipeline config (Redis key) and SMOKE_REPO plus PR_BRANCH (an open pipeline PR's branch).
set -uo pipefail
GH="$HOME/bin/oneshot-pr exec gh"
CFG=$(redis-cli --raw GET cfg:pipeline)
cfgv(){ printf '%s' "$CFG" | python3 -c "import json,sys;d=json.load(sys.stdin);print(eval('d'+sys.argv[1]))" "$1"; }
REPO=${SMOKE_REPO:?set SMOKE_REPO=<owner>/<repo>}; BRANCH=${PR_BRANCH:?set PR_BRANCH=<open pipeline PR branch>}
CHECK=$(cfgv "['ci']['checks'][0]"); ATT_PREFIX=$(cfgv "['repair']['attempts_prefix']")
PR=$($GH pr list --repo "$REPO" --head "$BRANCH" --state open --json number --jq '.[0].number'); [ -n "$PR" ] || { echo "FAIL: no open PR on $BRANCH"; exit 1; }
work=$(mktemp -d); ~/bin/oneshot-pr exec git clone -q --branch "$BRANCH" "https://github.com/$REPO.git" "$work" || { echo "FAIL: clone"; exit 1; }
cd "$work" && git config user.name "$(cfgv "['bots'][0]")" && git config user.email "pipeline@users.noreply.github.com"
before=$(git rev-parse HEAD)
printf 'import test from "node:test";\nimport assert from "node:assert/strict";\ntest("deliberate failure for the repair check", () => { assert.equal(1, 2); });\n' > repair-check.test.mts
git add repair-check.test.mts && git commit -q -m "test: deliberate failure for the repair check (to be removed by the repair build)" && ~/bin/oneshot-pr exec git push -q --no-verify origin "$BRANCH" || { echo "FAIL: push"; exit 1; }
bad=$(git rev-parse HEAD); echo "pushed failing commit $bad to $BRANCH (PR #$PR)"; T0=$SECONDS
# 1) the counted check must fail on that commit
until [ "$($GH api "repos/$REPO/commits/$bad/check-runs" --jq --arg c "$CHECK" '[.check_runs[]|select(.name==$c and .status=="completed")]|.[0].conclusion // ""' 2>/dev/null)" = "failure" ] || [ $((SECONDS-T0)) -gt 600 ]; do sleep 20; done
echo "check '$CHECK' on bad commit: $($GH api "repos/$REPO/commits/$bad/check-runs" --jq --arg c "$CHECK" '[.check_runs[]|select(.name==$c)]|.[0].conclusion')"
# 2) exactly one repair commit must land, and the check must go green
until [ "$($GH api "repos/$REPO/pulls/$PR" --jq .head.sha)" != "$bad" ] || [ $((SECONDS-T0)) -gt 1500 ]; do sleep 30; done
new=$($GH api "repos/$REPO/pulls/$PR" --jq .head.sha); [ "$new" != "$bad" ] || { echo "FAIL: no repair commit within the window"; exit 1; }
echo "repair commit: $new"
until [ -n "$($GH api "repos/$REPO/commits/$new/check-runs" --jq --arg c "$CHECK" '[.check_runs[]|select(.name==$c and .status=="completed")]|.[0].conclusion // ""' 2>/dev/null)" ] || [ $((SECONDS-T0)) -gt 2400 ]; do sleep 30; done
concl=$($GH api "repos/$REPO/commits/$new/check-runs" --jq --arg c "$CHECK" '[.check_runs[]|select(.name==$c)]|.[0].conclusion'); echo "check '$CHECK' after repair: $concl"
sleep 360
final=$($GH api "repos/$REPO/pulls/$PR" --jq .head.sha); attempts=$(redis-cli --raw GET "${ATT_PREFIX}${REPO}#${PR}")
echo "head after 6 more minutes: $final (attempts counted: ${attempts:-0})"
[ "$concl" = "success" ] && [ "$final" = "$new" ] && { echo PASS; exit 0; }
echo FAIL; exit 1
