#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Verifying bootstrap components...${NC}"

# Function to check if pods are ready
check_pods() {
    local namespace=$1
    local app=$2
    
    echo -n "Checking $app in $namespace... "
    
    if kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$app" &>/dev/null; then
        ready=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$app" -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' | grep -o "True" | wc -l)
        total=$(kubectl get pods -n "$namespace" -l "app.kubernetes.io/name=$app" --no-headers | wc -l)
        
        if [[ $ready -eq $total ]] && [[ $total -gt 0 ]]; then
            echo -e "${GREEN}✓ ($ready/$total ready)${NC}"
            return 0
        else
            echo -e "${RED}✗ ($ready/$total ready)${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ (not found)${NC}"
        return 1
    fi
}

# Check core components
echo -e "\n${YELLOW}Core Components:${NC}"
check_pods "kube-system" "cilium-agent"
check_pods "kube-system" "coredns"

# Check cert-manager
echo -e "\n${YELLOW}Certificate Management:${NC}"
check_pods "cert-manager" "cert-manager"
check_pods "cert-manager" "webhook"
check_pods "cert-manager" "cainjector"

# Check external-secrets
echo -e "\n${YELLOW}External Secrets:${NC}"
check_pods "external-secrets" "external-secrets"
check_pods "external-secrets" "external-secrets-webhook"
kubectl get pods -n external-secrets -l app=onepassword-connect -o jsonpath='{.items[*].status.phase}' | grep -q "Running" && echo -e "onepassword-connect ${GREEN}✓${NC}" || echo -e "onepassword-connect ${RED}✗${NC}"

# Check Flux
echo -e "\n${YELLOW}Flux Components:${NC}"
check_pods "flux-system" "flux-operator"

# Check if FluxInstance exists
echo -n "Checking FluxInstance... "
if kubectl get fluxinstance -n flux-system flux &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check critical secrets
echo -e "\n${YELLOW}Critical Secrets:${NC}"
echo -n "SOPS Age key... "
if kubectl get secret sops-age -n flux-system &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "1Password Connect secret... "
if kubectl get secret onepassword-connect-secret -n external-secrets &>/dev/null; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Check ClusterSecretStore
echo -n "ClusterSecretStore... "
if kubectl get clustersecretstore onepassword-connect &>/dev/null; then
    status=$(kubectl get clustersecretstore onepassword-connect -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
    if [[ "$status" == "True" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ (not ready)${NC}"
    fi
else
    echo -e "${RED}✗ (not found)${NC}"
fi

# Check Flux status
echo -e "\n${YELLOW}Flux Status:${NC}"
flux check || true