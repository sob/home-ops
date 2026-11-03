#!/bin/sh
# Import the cert-manager certificate into DSM and make it the default.
# Same DSM Web API calls as acme.sh's synology_dsm deploy hook. Importing with
# the existing certificate's id replaces it in place, so this is safe to rerun.
#
# TLS to DSM is verified, so DSM must already serve a valid certificate for
# DSM_URL: import the first one by hand (see cronjob.yaml).
# After that cert-manager renews 30 days before expiry and this runs weekly,
# so DSM's certificate is always still valid when the job connects.
set -eu

: "${DSM_URL:?}" "${DSM_USER:?}" "${DSM_PASS:?}" "${CERT_DESC:?}"
TLS=/tls
API="${DSM_URL}/webapi/entry.cgi"
CURL="curl -fsS --max-time 60"

# tls.crt is the leaf followed by the chain; DSM wants them separately.
awk 'n < 1 { print } /END CERTIFICATE/ { n++ }' "$TLS/tls.crt" > /tmp/cert.pem
awk 'n >= 1 { print } /END CERTIFICATE/ { n++ }' "$TLS/tls.crt" > /tmp/chain.pem

login=$($CURL "$API" \
  --data-urlencode api=SYNO.API.Auth --data-urlencode version=6 \
  --data-urlencode method=login --data-urlencode session=Certificate \
  --data-urlencode format=sid --data-urlencode enable_syno_token=yes \
  --data-urlencode "account=${DSM_USER}" --data-urlencode "passwd=${DSM_PASS}")
if [ "$(echo "$login" | jq -r .success)" != true ]; then
  echo "login failed: $(echo "$login" | jq -c .error)" >&2
  exit 1
fi
sid=$(echo "$login" | jq -r .data.sid)
token=$(echo "$login" | jq -r .data.synotoken)
trap '$CURL "$API?api=SYNO.API.Auth&version=6&method=logout&session=Certificate&_sid=${sid}" >/dev/null || true' EXIT

# Replace the certificate imported before (matched by description), if any.
id=$($CURL "$API" -H "X-SYNO-TOKEN: ${token}" \
  --data-urlencode api=SYNO.Core.Certificate.CRT --data-urlencode version=1 \
  --data-urlencode method=list --data-urlencode "_sid=${sid}" |
  jq -r --arg d "$CERT_DESC" '[.data.certificates[] | select(.desc == $d) | .id][0] // ""')

result=$($CURL "$API?api=SYNO.Core.Certificate&version=1&method=import&SynoToken=${token}&_sid=${sid}" \
  -F "key=@${TLS}/tls.key" -F "cert=@/tmp/cert.pem" -F "inter_cert=@/tmp/chain.pem" \
  -F "id=${id}" -F "desc=${CERT_DESC}" -F "as_default=true")
if [ "$(echo "$result" | jq -r .success)" != true ]; then
  echo "import failed: $(echo "$result" | jq -c .error)" >&2
  exit 1
fi
echo "imported ${CERT_DESC} (${id:-new})"
