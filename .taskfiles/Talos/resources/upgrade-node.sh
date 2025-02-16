#!/bin/bash
set -euo pipefail

NODE_IP=$1
TALOS_IMAGE=$2

echo "Detecting node type..."
NODE_TYPE=$(talosctl --nodes "${NODE_IP}" get machineconfig -o yaml | yq '.spec.machine.type')

echo "Getting node name from kubernetes..."
NODE_NAME=$(kubectl get nodes -o json | jq -r '.items[] | select(.status.addresses[] | select(.type=="InternalIP" and .address=="'"${NODE_IP}"'")) | .metadata.name')
if [ -z "${NODE_NAME}" ]; then
    echo "✗ Could not determine node name"
    exit 1
fi
echo "✓ Found node: ${NODE_NAME}"

echo "Upgrading ${NODE_TYPE} node ${NODE_IP}"
talosctl --nodes "${NODE_IP}" upgrade --image="${TALOS_IMAGE}" --timeout=10m

echo "Waiting for node ${NODE_NAME} to be ready..."
# Wait for node to be Ready
if ! kubectl wait --for=condition=ready node/${NODE_NAME} --timeout=5m; then
    echo "✗ Node failed to become ready"
    exit 1
fi
echo "✓ Node is ready in kubernetes"

# If control plane node, wait for apiserver
if [ "${NODE_TYPE}" = "controlplane" ]; then
    echo "Waiting for apiserver..."
    if ! kubectl wait pods -n kube-system -l component=kube-apiserver --field-selector spec.nodeName=${NODE_NAME} --for=condition=ready --timeout=5m; then
        echo "✗ API server failed to become ready"
        exit 1
    fi
    echo "✓ API server is ready"
fi

echo "✓ Node upgrade complete"
