#!/usr/bin/env bash
set -euo pipefail

APP="${1:-}"
NS="${2:-}"

if [[ -z "$APP" || -z "$NS" ]]; then
    echo "Usage: $0 <app> <namespace>"
    exit 1
fi

echo "Deleting restic snapshots from repository..."

# Find restic repository secrets
secrets=$(kubectl get secrets -n "$NS" -o name 2>/dev/null | grep -E "volsync-.*${APP}.*restic-config" | cut -d/ -f2 || true)

if [[ -z "$secrets" ]]; then
    echo "No restic repository secrets found for ${APP}"
    exit 0
fi

for secret in $secrets; do
    echo "Found restic config: $secret"
    
    # Extract repository info from secret
    RESTIC_REPOSITORY=$(kubectl get secret -n "$NS" "$secret" -o jsonpath='{.data.RESTIC_REPOSITORY}' 2>/dev/null | base64 -d || true)
    
    if [[ -z "$RESTIC_REPOSITORY" ]]; then
        echo "Could not extract repository from $secret"
        continue
    fi
    
    echo "Creating job to delete snapshots from: $RESTIC_REPOSITORY"
    
    # Generate unique job name
    JOB_NAME="delete-restic-snapshots-${APP}-$(date +%s)"
    
    # Create the job YAML
    cat <<EOF | kubectl apply -f - 2>/dev/null || { echo "Failed to create job for $secret"; continue; }
apiVersion: batch/v1
kind: Job
metadata:
  name: ${JOB_NAME}
  namespace: ${NS}
spec:
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: restic
        image: restic/restic:latest
        command: ["/bin/sh", "-c"]
        args:
        - |
          set +e  # Don't exit on error
          echo "Checking restic repository..."
          if restic snapshots 2>/dev/null; then
            echo "Found snapshots, removing all..."
            restic forget --prune --keep-last 0 2>/dev/null || echo "Failed to delete snapshots"
          else
            echo "No snapshots found or repository not accessible"
          fi
          echo "Restic cleanup complete"
        envFrom:
        - secretRef:
            name: ${secret}
EOF
    
    # Wait for job to complete
    echo "Waiting for job to complete..."
    kubectl wait --for=condition=complete "job/${JOB_NAME}" -n "$NS" --timeout=120s 2>/dev/null || true
    
    # Check job logs
    kubectl logs "job/${JOB_NAME}" -n "$NS" 2>/dev/null || true
done

echo "Restic snapshot deletion complete"