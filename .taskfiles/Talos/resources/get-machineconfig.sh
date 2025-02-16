#!/bin/bash
set -euo pipefail

NODE_IP=$1
TEMPLATE_PATH=$2
OUTPUT_DIR=$3

echo "Getting machineconfig..."
talosctl --nodes "${NODE_IP}" get machineconfig -o yaml > /tmp/debug.yaml

echo "Processing config..."
yq 'select(.kind == "MachineConfig") | .spec |
  with(.machine.kubelet.image; . style="double") |
  with(.machine.install.image; . style="double")' /tmp/debug.yaml | \
yq eval '
  with(.machine.kubelet.image; select(.) |= sub(":v[0-9]+\.[0-9]+\.[0-9]+.*$", ":${KUBERNETES_VERSION}")) |
  with(.machine.install.image; select(.) |= sub(":[^:]+$", ":${TALOS_VERSION}"))
' - | \
sops --encrypt - > "${OUTPUT_DIR}/${NODE_IP}.sops.yaml"

rm /tmp/debug.yaml