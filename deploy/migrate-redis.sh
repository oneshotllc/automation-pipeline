#!/usr/bin/env bash
# Copy every key from one Redis to another, preserving TTLs (strings and lists only; that is all NodeMation uses).
# usage: migrate-redis.sh <src-port> <dst-port>
set -euo pipefail
SRC=${1:?src port}; DST=${2:?dst port}
n=0
for k in $(redis-cli -p "$SRC" --raw KEYS '*'); do
  t=$(redis-cli -p "$SRC" --raw TYPE "$k"); ttl=$(redis-cli -p "$SRC" --raw TTL "$k")
  case "$t" in
    string) v=$(redis-cli -p "$SRC" --raw GET "$k"); redis-cli -p "$DST" SET "$k" "$v" >/dev/null ;;
    list)   redis-cli -p "$DST" DEL "$k" >/dev/null; redis-cli -p "$SRC" --raw LRANGE "$k" 0 -1 | while IFS= read -r item; do redis-cli -p "$DST" RPUSH "$k" "$item" >/dev/null; done ;;
    *) echo "skip $k ($t)"; continue ;;
  esac
  [ "$ttl" -gt 0 ] && redis-cli -p "$DST" EXPIRE "$k" "$ttl" >/dev/null
  n=$((n+1))
done
echo "migrated $n keys: src=$(redis-cli -p $SRC DBSIZE) dst=$(redis-cli -p $DST DBSIZE)"
