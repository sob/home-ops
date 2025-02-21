#!/bin/bash

set -e

NAMESPACE="${1}"
CLUSTER="${2}"

# Verify arguments
if [ -z "$NAMESPACE" ] || [ -z "$CLUSTER" ]; then
    echo "Usage: $0 <namespace> <cluster>"
    exit 1
fi

# Check if cluster exists
if ! kubectl get cluster "$CLUSTER" -n "$NAMESPACE" &>/dev/null; then
    echo "Cluster $CLUSTER not found in namespace $NAMESPACE"
    exit 1
fi

# Confirm deletion
echo "WARNING: You are about to delete cluster $CLUSTER in namespace $NAMESPACE"
echo "This will delete all data associated with this cluster."
read -p "Are you sure you want to proceed? (y/N): " confirm

if [[ "$confirm" != [yY] && "$confirm" != [yY][eE][sS] ]]; then
    echo "Deletion cancelled."
    exit 0
fi

# Clear finalizers from pods in the cluster
echo "Clearing finalizers from pods..."
for pod in $(kubectl get pods -n "$NAMESPACE" -l cnpg.io/cluster="$CLUSTER" -o name); do
  echo "Removing finalizers from $pod"
  kubectl patch $pod -n "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge
done

# Delete the cluster with potential force if needed
echo "Deleting cluster $CLUSTER..."
kubectl delete cluster "$CLUSTER" -n "$NAMESPACE" --timeout=30s || {
  echo "Standard deletion timed out, attempting force deletion..."
  # If normal delete fails, patch to remove finalizers and force delete
  kubectl patch cluster "$CLUSTER" -n "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge
  kubectl delete cluster "$CLUSTER" -n "$NAMESPACE" --force --grace-period=0
}

echo "Cluster $CLUSTER deleted."
