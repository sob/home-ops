#!/usr/bin/env bash
# Validate HelmRelease manifests against the JSON Schema declared in their
#   # yaml-language-server: $schema=<url>
# modeline. This is the layer kubeconform cannot provide: kubeconform validates
# the HelmRelease CRD but treats spec.values as opaque, so chart values — most
# importantly the bjw-s app-template values — go unchecked. This catches the
# indentation / typo / wrong-type mistakes that slip in when editing by hand.
#
# Scope is deliberately HelmReleases only: every other kind (PrometheusRule,
# OCIRepository, Kustomization, ExternalSecret, ...) is already covered by
# kubeconform, and some of those upstream schemas don't pass Python's stricter
# metaschema checks.
#
# Usage:
#   validate-schemas.sh [file ...]   # pre-commit passes changed files
#   validate-schemas.sh              # scan ${KUBERNETES_DIR:-./kubernetes}
#
# Requires: check-jsonschema (provided via mise / pipx).
set -euo pipefail

KUBERNETES_DIR="${KUBERNETES_DIR:-./kubernetes}"

if ! command -v check-jsonschema >/dev/null 2>&1; then
  echo "ERROR: check-jsonschema not found. Run: mise install" >&2
  exit 127
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Emit "<schema-url>\t<file>" for each HelmRelease that declares a schema modeline.
collect() {
  file="$1"
  case "$file" in
    *.sops.yaml) return 0 ;;
  esac
  [ -f "$file" ] || return 0
  grep -q '^kind: HelmRelease' "$file" 2>/dev/null || return 0
  url="$(grep -m1 -oE '\$schema=[^[:space:]]+' "$file" 2>/dev/null | sed -E 's/^\$schema=//')" || true
  [ -n "${url:-}" ] || return 0
  printf '%s\t%s\n' "$url" "$file" >>"$tmp"
}

if [ "$#" -gt 0 ]; then
  for f in "$@"; do collect "$f"; done
else
  while IFS= read -r f; do
    collect "$f"
  done < <(grep -rlE '\$schema=' --include='*.yaml' "$KUBERNETES_DIR" 2>/dev/null)
fi

if [ ! -s "$tmp" ]; then
  echo "No HelmReleases with schema modelines to validate."
  exit 0
fi

# Validate one batch per unique schema URL (the 48 app-template releases share
# one URL, so this is a single fast invocation rather than one process per file).
rc=0
cur=""
files=()
flush() {
  [ "${#files[@]}" -gt 0 ] || return 0
  # --disable-formats: we care about structure/types/required keys, not string
  # formats (and Python's format checkers differ from the ECMA ones schemas assume).
  if ! check-jsonschema --disable-formats '*' --schemafile "$cur" "${files[@]}"; then
    rc=1
  fi
}

while IFS="$(printf '\t')" read -r url file; do
  if [ "$url" != "$cur" ]; then
    flush
    cur="$url"
    files=()
  fi
  files+=("$file")
done < <(sort "$tmp")
flush

if [ "$rc" -eq 0 ]; then
  echo "✓ HelmRelease schema validation passed"
else
  echo "✗ HelmRelease schema validation failed" >&2
fi
exit "$rc"
