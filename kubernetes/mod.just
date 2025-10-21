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

[doc('sync gitrepositories')]
sync-git:
  kubectl get gitrepo --no-headers -A | while read -r ns name _; do \
    kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite gitrepo "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
  done

[doc('sync helmreleases')]
sync-hr:
  kubectl get hr --no-headers -A | while read -r ns name _; do \
    kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite hr "$name" reconcile.fluxcd.io/requestedAt="$(date +%s)"; \
  done

[doc('toggle helmrelease')]
toggle-hr namespace hr:
  kubectl patch hr "{{ hr }}" --namespace "{{ namespace }}" --type=merge -p '{"spec":{"suspend":true}}' && \
  helm delete "{{ hr }}" --namespace "{{ namespace }}" --no-hooks && \
  kubectl patch hr "{{ hr }}" --namespace "{{ namespace }}" --type=merge -p '{"spec":{"suspend":false}}'

