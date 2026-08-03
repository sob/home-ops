#!/usr/bin/env bash
set -euo pipefail

MODE="${MODE:-days}"
DAYS="${DAYS_THRESHOLD:-30}"
DRY_RUN="${DRY_RUN:-true}"

UNIFI_URL=$(op read "op://STONEHEDGES/unifi/URL")
API_KEY=$(op read "op://STONEHEDGES/unifi/API_KEY")
SITE="${UNIFI_SITE:-default}"

UNIFI_URL="${UNIFI_URL%/}"

echo "UniFi URL: ${UNIFI_URL}"
echo "Mode:      ${MODE}"
echo "Dry run:   ${DRY_RUN}"

if [ "$MODE" = "offline" ]; then
  echo ""
  echo "Fetching active clients..."
  ACTIVE_MACS=$(curl -ksS \
    -H "X-API-KEY: ${API_KEY}" \
    "${UNIFI_URL}/proxy/network/api/s/${SITE}/stat/sta" \
    | jq -r '[.data[].mac] | sort')

  echo "Fetching all known clients..."
  CLIENTS=$(curl -ksS \
    -H "X-API-KEY: ${API_KEY}" \
    "${UNIFI_URL}/proxy/network/api/s/${SITE}/rest/user")

  TOTAL=$(echo "$CLIENTS" | jq '.data | length')
  ACTIVE_COUNT=$(echo "$ACTIVE_MACS" | jq 'length')
  echo "Total known clients: ${TOTAL}"
  echo "Currently connected:  ${ACTIVE_COUNT}"

  STALE=$(echo "$CLIENTS" | jq -c --argjson active "$ACTIVE_MACS" \
    '[.data[] | select(.mac as $m | ($active | index($m)) | not)]')
  STALE_COUNT=$(echo "$STALE" | jq 'length')

  echo "Offline clients:      ${STALE_COUNT}"
else
  CUTOFF=$(( $(date +%s) - 86400 * DAYS ))
  echo "Threshold: ${DAYS} days (cutoff: $(date -r "${CUTOFF}" '+%Y-%m-%d'))"
  echo ""

  echo "Fetching known clients..."
  CLIENTS=$(curl -ksS \
    -H "X-API-KEY: ${API_KEY}" \
    "${UNIFI_URL}/proxy/network/api/s/${SITE}/rest/user")

  TOTAL=$(echo "$CLIENTS" | jq '.data | length')
  echo "Total known clients: ${TOTAL}"

  STALE=$(echo "$CLIENTS" | jq -c --argjson cutoff "$CUTOFF" \
    '[.data[] | select((.last_seen < $cutoff and .last_seen > 0) or .last_seen == null)]')
  STALE_COUNT=$(echo "$STALE" | jq 'length')
fi

echo "Clients to prune: ${STALE_COUNT}"
echo ""

if [ "$STALE_COUNT" -eq 0 ]; then
  echo "Nothing to prune."
  exit 0
fi

echo "$STALE" | jq -r \
  'sort_by(.last_seen // 0) | .[] |
   "\(.mac)\t\(if .last_seen and .last_seen > 0 then (.last_seen | todateiso8601) else "never" end)\t\(.hostname // .name // "unnamed")"' \
  | column -t -s $'\t' \
  | head -20

if [ "$STALE_COUNT" -gt 20 ]; then
  echo "... and $((STALE_COUNT - 20)) more"
fi
echo ""

if [ "$DRY_RUN" = "true" ]; then
  echo "Dry run — no clients removed. Set DRY_RUN=false to prune."
  exit 0
fi

MACS=$(echo "$STALE" | jq '[.[].mac]')

echo "$MACS" | jq -c '[limit(50; .[])]' > /dev/null 2>&1 || true

BATCH_SIZE=50
TOTAL_MACS=$(echo "$MACS" | jq 'length')
OFFSET=0

while [ "$OFFSET" -lt "$TOTAL_MACS" ]; do
  BATCH=$(echo "$MACS" | jq -c ".[$OFFSET:$((OFFSET + BATCH_SIZE))]")
  BATCH_LEN=$(echo "$BATCH" | jq 'length')
  echo "Forgetting clients $((OFFSET + 1))-$((OFFSET + BATCH_LEN)) of ${TOTAL_MACS}..."

  RESULT=$(curl -ksS -X POST \
    -H "X-API-KEY: ${API_KEY}" \
    -H "Content-Type: application/json" \
    "${UNIFI_URL}/proxy/network/api/s/${SITE}/cmd/stamgr" \
    -d "{\"cmd\":\"forget-sta\",\"macs\":${BATCH}}")

  RC=$(echo "$RESULT" | jq -r '.meta.rc // "error"')
  if [ "$RC" != "ok" ]; then
    echo "ERROR: batch starting at offset ${OFFSET} failed:"
    echo "$RESULT" | jq .
    exit 1
  fi

  OFFSET=$((OFFSET + BATCH_SIZE))
  [ "$OFFSET" -lt "$TOTAL_MACS" ] && sleep 2
done

echo ""
echo "Done. Pruned ${TOTAL_MACS} stale clients."
