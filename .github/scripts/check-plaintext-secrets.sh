#!/usr/bin/env bash
# Flag YAML that appears to assign a plaintext secret value — the low-entropy
# literals (e.g. `password: hunter2`) that gitleaks' pattern/entropy rules can
# miss. Complements, not replaces, gitleaks.
#
# Skips *.sops.yaml (encrypted) and ignores values that are clearly not literals:
# templating refs (${...}, {{ }}), YAML anchors/aliases (&/*), and lines that
# reference a Secret (secretRef/secretKeyRef/secretName/kind: Secret).
#
# Run as a script file (not inline) so pre-commit's argv splitting can't mangle
# the quoting.
set -euo pipefail

rc=0
for file in "$@"; do
  case "$file" in
    *.sops.yaml) continue ;;
  esac
  [ -f "$file" ] || continue

  # key: <literal>  — optional opening quote, then a char that is not a space,
  # quote, templating ($,{), or anchor/alias (&,*).
  if grep -nEi '^[[:space:]]*(password|passwd|secret|token):[[:space:]]*["'\'']?[^][:space:]"'\''$&{*]' "$file" 2>/dev/null \
      | grep -viE 'secretRef|secretKeyRef|secretName|configMapKeyRef|kind:[[:space:]]*Secret'; then
    echo "ERROR: ${file} may contain a plaintext secret — encrypt with SOPS or use External Secrets" >&2
    rc=1
  fi
done

exit "$rc"
