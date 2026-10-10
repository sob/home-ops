#!/usr/bin/env bash
# Guard rails for Tinyauth forward-auth. Fails when:
#   1. a Tinyauth `apps` entry is missing config.domain, users.allow or
#      oauth.groups. Under acls.policy deny, an entry without oauth.groups
#      admits ANY OAuth user, so a missing field quietly opens the app.
#   2. a SecurityPolicy that calls Tinyauth fails open or skips the nginx
#      adapter (port 8082). Calling Tinyauth's Envoy mode directly (:3000)
#      reintroduces the path-rule bypass fixed in #1874.
#   3. a launcher tile (apps.json) not marked "everyone" has no Tinyauth
#      entry for its host, so the launcher could never show it.
#
# Requires: yq, jq (provided via mise).
set -euo pipefail

KUBERNETES_DIR="${KUBERNETES_DIR:-./kubernetes}"
TA="$KUBERNETES_DIR/apps/security/tinyauth/app"
fail=0
err() { echo "ERROR: $*" >&2; fail=1; }

# Tinyauth's config is an ExternalSecret template. Replace the {{ }}
# expressions with a placeholder so it parses as plain YAML.
config="$(yq '.spec.target.template.data["config.yaml"]' "$TA/externalsecret.yaml" |
  sed -E 's/"\{\{[^}]*\}\}"/"x"/g; s/\{\{[^}]*\}\}/"x"/g')"
apps="$(yq -o json '.apps // {}' <<<"$config")"

# 1. every entry is complete
while IFS= read -r name; do
  for field in config.domain users.allow oauth.groups; do
    v="$(jq -r --arg n "$name" --arg f "$field" '.[$n] | getpath($f | split(".")) // "" | tostring' <<<"$apps")"
    [[ -n "$v" && "$v" != "null" ]] || err "tinyauth app '$name' has no $field"
  done
done < <(jq -r 'keys[]' <<<"$apps")

# 2. every Tinyauth SecurityPolicy fails closed through the adapter
while IFS= read -r -d '' f; do
  yq -o json -I0 'select(.kind == "SecurityPolicy")' "$f" 2>/dev/null |
    jq -c 'select(.spec.extAuth.http.backendRefs[]?.name == "tinyauth")' |
    while IFS= read -r sp; do
      id="$(jq -r '.metadata.namespace + "/" + .metadata.name' <<<"$sp")"
      [[ "$(jq -r '.spec.extAuth.failOpen' <<<"$sp")" == "false" ]] ||
        { echo "ERROR: $f ($id): extAuth.failOpen must be false" >&2; echo fail; }
      [[ "$(jq -r '[.spec.extAuth.http.backendRefs[] | select(.name == "tinyauth") | .port] | unique | join(",")' <<<"$sp")" == "8082" ]] ||
        { echo "ERROR: $f ($id): tinyauth backend must use port 8082 (the ext-auth adapter)" >&2; echo fail; }
    done
done < <(find "$KUBERNETES_DIR" -name '*.yaml' -print0) | grep -q fail && fail=1

# 3. every launcher tile behind Tinyauth has an entry for its host
domains="$(jq -r '[.[].config.domain] | join(" ")' <<<"$apps")"
while IFS= read -r host; do
  [[ " $domains " == *" $host "* ]] || err "apps.json: $host is not marked \"everyone\" but has no tinyauth apps entry"
done < <(jq -r '.apps[] | select(.everyone != true) | .url | sub("^https?://"; "") | sub("[/:].*$"; "")' "$TA/resources/apps.json")

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi
echo "tinyauth: $(jq 'length' <<<"$apps") apps, policies and launcher consistent"
