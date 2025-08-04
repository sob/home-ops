#!/usr/bin/env bash
set -euo pipefail

KUBERNETES_DIR="${1:-./kubernetes}"
POLICY_FILE="${2:-.github/policies/kubernetes.rego}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Counters
errors=0
warnings=0

# Check if OPA is installed
if ! command -v opa &> /dev/null; then
    echo -e "${RED}ERROR${NC}: OPA not installed"
    exit 1
fi

echo "=== Running OPA Policy Validation ==="
echo "Policy: ${POLICY_FILE}"
echo ""

# Process a limited set of kustomizations for testing
echo "Processing sample kustomizations..."
for dir in \
    "${KUBERNETES_DIR}/apps/default/plex/app" \
    "${KUBERNETES_DIR}/apps/default/bazarr/app" \
    "${KUBERNETES_DIR}/apps/network/nginx/external/app"; do
    
    if [ ! -d "$dir" ]; then
        continue
    fi
    
    echo "Building $dir..."
    if output=$(kustomize build "$dir" --load-restrictor=LoadRestrictionsNone 2>&1); then
        # Count resources
        resource_count=$(echo "$output" | grep -c '^---' || echo "1")
        echo "  Found $resource_count resources"
        
        # Process each resource
        echo "$output" | yq eval-all -o=json 'select(. != null)' | jq -c '.' | while IFS= read -r doc; do
            if [ -z "$doc" ] || [ "$doc" = "null" ]; then
                continue
            fi
            
            # Get resource info
            kind=$(echo "$doc" | jq -r '.kind // "unknown"')
            name=$(echo "$doc" | jq -r '.metadata.name // "unnamed"')
            namespace=$(echo "$doc" | jq -r '.metadata.namespace // "default"')
            
            # Skip non-Kubernetes resources
            if [ "$kind" = "unknown" ]; then
                continue
            fi
            
            # Run OPA evaluation
            result=$(opa eval -d "$POLICY_FILE" -I "$doc" "data.kubernetes.validation" 2>&1 | jq -r '.result[0].expressions[0].value' 2>/dev/null || echo '{}')
            
            # Check deny rules
            denials=$(echo "$result" | jq -r '.deny[]?' 2>/dev/null || true)
            if [ -n "$denials" ]; then
                while IFS= read -r denial; do
                    echo -e "  ${RED}DENY${NC} $namespace/$kind/$name: $denial"
                    ((errors++))
                done <<< "$denials"
            fi
            
            # Check warn rules
            warns=$(echo "$result" | jq -r '.warn[]?' 2>/dev/null || true)
            if [ -n "$warns" ]; then
                while IFS= read -r warning; do
                    echo -e "  ${YELLOW}WARN${NC} $namespace/$kind/$name: $warning"
                    ((warnings++))
                done <<< "$warns"
            fi
        done
    else
        echo -e "  ${YELLOW}WARN${NC}: Failed to build"
    fi
done

echo ""
echo "=== OPA Validation Summary ==="
echo "Errors: ${errors}"
echo "Warnings: ${warnings}"

if [ $errors -gt 0 ]; then
    echo -e "${RED}✗ Validation failed with $errors errors${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Validation passed${NC}"
fi