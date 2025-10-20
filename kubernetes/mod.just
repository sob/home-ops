set quiet := true
set shell := ['bash', '-euo', 'pipefail', '-c']

kubernetes_dir := justfile_dir() + '/kubernetes'

[private]
default:
    just -l kube

[doc('Sync ExternalSecrets')]
sync-es:
  kubectl get es --no-headers -A | while read -r ns name _; do \
    kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite es "$name" force-sync="$(date +%s)"; \
  done
