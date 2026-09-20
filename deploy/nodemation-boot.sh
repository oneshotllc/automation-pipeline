#!/usr/bin/env bash
# Boot glue for the Mac Studio (approved by Brian 2026-09-19): bring the NodeMation runtime and its host-side
# dependencies back after a reboot without anyone logging in. Idempotent; safe to run any time.
# Installed as the single user-crontab line:  @reboot /Users/oneshot-agent/bin/nodemation-boot
# It starts infrastructure only. It never touches queues, tickets, or workflows; that is n8n's job.
export PATH=/opt/homebrew/bin:/opt/homebrew/opt/node@22/bin:/usr/local/bin:/usr/bin:/bin
export HOME=/Users/oneshot-agent
LOG=$HOME/.hermes/logs/nodemation-boot.log; mkdir -p "$(dirname "$LOG")"
log(){ echo "$(date -u +%FT%TZ) $*" >> "$LOG"; }
log "boot script start (uid $(id -u))"
# 1. wait for the network (up to 3 min)
for i in $(seq 1 36); do curl -s -m 3 -o /dev/null https://api.github.com && break; sleep 5; done
# 2. colima + the compose stack
if ! colima status >/dev/null 2>&1; then log "starting colima"; colima start --cpu 4 --memory 6 --disk 60 >>"$LOG" 2>&1 || log "colima start failed"; fi
if ( cd "$HOME/code/oneshotllc-automation/deploy" && docker compose up -d >>"$LOG" 2>&1 ); then log "compose up ok"; else log "compose up failed"; fi
# 3. host-side dependencies that stay outside the stack by design
pgrep -f 'claude-shim/server.js' >/dev/null || { ( cd "$HOME/claude-shim" && nohup node --env-file=.env server.js >> logs/shim.log 2>&1 & ) ; log "claude shim started"; }
pgrep -f 'caddy run --config /Users/oneshot-agent/.hermes/Caddyfile' >/dev/null || { nohup caddy run --config "$HOME/.hermes/Caddyfile" >> "$HOME/.hermes/logs/caddy.nohup.log" 2>&1 & log "hermes caddy started"; }
pgrep -f 'Runner.Listener' >/dev/null || { ( cd "$HOME/actions-runner-oneshotllc" && nohup ./run.sh >> "$HOME/.hermes/logs/runner.nohup.log" 2>&1 & ) ; log "github runner started"; }
# 4. report
for i in $(seq 1 30); do curl -s -m 2 -o /dev/null -w '%{http_code}' http://127.0.0.1:5678/healthz | grep -q 200 && break; sleep 4; done
log "n8n healthz=$(curl -s -m 3 http://127.0.0.1:5678/healthz) redis=$(redis-cli PING 2>&1 | head -c 8) gate=$(curl -s -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:8460/) shim=$(curl -s -m 3 -o /dev/null -w '%{http_code}' http://127.0.0.1:8790/v1/models) caddy8444=$(curl -sk -m 3 -o /dev/null -w '%{http_code}' https://127.0.0.1:8444/) runner=$(pgrep -f Runner.Listener | wc -l | tr -d " ")"
log "boot script done"
