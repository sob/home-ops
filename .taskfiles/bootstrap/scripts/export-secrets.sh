#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Exporting secrets from current cluster...${NC}"

# Export SOPS Age key
if kubectl get secret sops-age -n flux-system &>/dev/null; then
    echo -e "${GREEN}Exporting SOPS Age key...${NC}"
    SOPS_AGE_KEY=$(kubectl get secret sops-age -n flux-system -o jsonpath='{.data.age\.agekey}')
    echo "export SOPS_AGE_KEY_BASE64='${SOPS_AGE_KEY}'"
else
    echo -e "${RED}SOPS Age secret not found${NC}"
fi

# Export 1Password credentials
if kubectl get secret onepassword-connect-secret -n external-secrets &>/dev/null; then
    echo -e "${GREEN}Exporting 1Password credentials...${NC}"
    OP_CREDS=$(kubectl get secret onepassword-connect-secret -n external-secrets -o jsonpath='{.data.1password-credentials\.json}' | base64 -d)
    OP_TOKEN=$(kubectl get secret onepassword-connect-secret -n external-secrets -o jsonpath='{.data.token}' | base64 -d)
    
    echo "export ONEPASSWORD_CREDENTIALS_JSON='${OP_CREDS}'"
    echo "export ONEPASSWORD_TOKEN='${OP_TOKEN}'"
else
    echo -e "${RED}1Password Connect secret not found${NC}"
fi

# Try to get vault ID from ClusterSecretStore
if kubectl get clustersecretstore onepassword-connect &>/dev/null; then
    echo -e "${GREEN}Detecting 1Password vault ID...${NC}"
    VAULT_ID=$(kubectl get clustersecretstore onepassword-connect -o jsonpath='{.spec.provider.onepassword.vaults.home}' 2>/dev/null || echo "")
    if [[ -n "${VAULT_ID}" ]]; then
        echo "export ONEPASSWORD_VAULT_ID='${VAULT_ID}'"
    fi
fi

echo -e "${YELLOW}Add these exports to your shell environment or .envrc file${NC}"