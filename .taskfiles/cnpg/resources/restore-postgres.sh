#!/bin/bash

set -e

NAMESPACE="${1}"
CLUSTER="${2}"
BACKUP_NAME="${3}"
CLUSTER_FILE="${4}"

# Verify arguments
if [ -z "$NAMESPACE" ] || [ -z "$CLUSTER" ] || [ -z "$BACKUP_NAME" ] || [ -z "$CLUSTER_FILE" ]; then
    echo "Usage: $0 <namespace> <cluster> <backup-name> <cluster-file>"
    exit 1
fi

# Verify backup exists and is completed
if ! kubectl get backup "$BACKUP_NAME" -n "$NAMESPACE" -o jsonpath='{.status.phase}' | grep -q "completed"; then
    echo "Backup $BACKUP_NAME not found or not completed in namespace $NAMESPACE"
    exit 1
fi

# Get current restore number and increment
CURRENT_RESTORE=$(kubectl get cluster -n "$NAMESPACE" | grep "${CLUSTER}-[0-9]\{3\}" | grep -o '[0-9]\{3\}$' || echo "000")
NEXT_RESTORE=$(printf "%03d" $((10#$CURRENT_RESTORE + 1)))
NEW_CLUSTER_NAME="${CLUSTER}-${NEXT_RESTORE}"

# Update cluster manifest
yq eval -i \
    ".metadata.name = \"${NEW_CLUSTER_NAME}\" |
     .spec.bootstrap = {\"recovery\": {\"backup\": {\"name\": \"${BACKUP_NAME}\"}}} |
     .spec.backup.barmanObjectStore.serverName = \"${NEW_CLUSTER_NAME}\" |
     .spec.externalClusters[0].name = \"${NEW_CLUSTER_NAME}\" |
     .spec.externalClusters[0].barmanObjectStore.serverName = \"${NEW_CLUSTER_NAME}\"" \
    "$CLUSTER_FILE"

echo "Updated cluster manifest with new name $NEW_CLUSTER_NAME using backup $BACKUP_NAME"
echo "Review changes and commit when ready"
git diff ${CLUSTER_FILE}
