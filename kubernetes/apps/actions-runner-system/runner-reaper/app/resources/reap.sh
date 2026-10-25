#!/bin/sh
# Force-delete ARC runner pods stranded on a node that has been NotReady for
# longer than GRACE_SECONDS. Kubernetes can't finish deleting a pod on a dead
# node, so it sits in Terminating forever; the scale set keeps counting it as a
# busy runner and never starts a replacement, and queued jobs wait indefinitely.
# Runners are ephemeral, so the only thing lost is the job that already died.
set -eu

ns="${NAMESPACE:?}"
grace="${GRACE_SECONDS:-600}"

dead=$(kubectl get nodes -o json | jq -r --argjson now "$(date +%s)" --argjson grace "$grace" '
  .items[]
  | select(any(.status.conditions[];
      .type == "Ready" and .status != "True"
      and ($now - (.lastTransitionTime | fromdateiso8601)) > $grace))
  | .metadata.name')

[ -n "$dead" ] || exit 0

for node in $dead; do
  for pod in $(kubectl -n "$ns" get pods -l actions-ephemeral-runner=True \
      --field-selector "spec.nodeName=$node" -o jsonpath='{.items[*].metadata.name}'); do
    echo "node $node is NotReady: removing runner $pod"
    kubectl -n "$ns" delete pod "$pod" --force --grace-period=0 --wait=false
    # The EphemeralRunner shares the pod's name; deleting it frees the slot.
    kubectl -n "$ns" delete ephemeralrunner "$pod" --ignore-not-found --wait=false
  done
done
