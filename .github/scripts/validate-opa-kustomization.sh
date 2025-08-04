#!/usr/bin/env bash
set -euo pipefail

# Usage: validate-opa-kustomization.sh <kustomization-path> [policy-file]
KUSTOMIZATION_PATH="${1:-}"
POLICY_FILE="${2:-.github/policies/kubernetes.rego}"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Check arguments
if [ -z "$KUSTOMIZATION_PATH" ]; then
    echo "Usage: $0 <kustomization-path> [policy-file]"
    echo "Example: $0 kubernetes/apps/default/plex/app"
    exit 1
fi

if [ ! -d "$KUSTOMIZATION_PATH" ]; then
    echo -e "${RED}ERROR${NC}: Directory not found: $KUSTOMIZATION_PATH"
    exit 1
fi

if [ ! -f "$KUSTOMIZATION_PATH/kustomization.yaml" ]; then
    echo -e "${RED}ERROR${NC}: No kustomization.yaml found in: $KUSTOMIZATION_PATH"
    exit 1
fi

# Check if OPA is installed
if ! command -v opa &> /dev/null; then
    echo -e "${RED}ERROR${NC}: OPA not installed. Install with: brew install opa"
    exit 1
fi

echo "=== OPA Validation for Kustomization ==="
echo "Path: $KUSTOMIZATION_PATH"
echo "Policy: $POLICY_FILE"
echo ""

# Build the kustomization
echo "Building kustomization..."
if ! output=$(kustomize build "$KUSTOMIZATION_PATH" --load-restrictor=LoadRestrictionsNone 2>&1); then
    echo -e "${RED}ERROR${NC}: Failed to build kustomization"
    echo "$output"
    exit 1
fi

# Convert to JSON and save to temp file
TEMP_JSON=$(mktemp)
trap "rm -f $TEMP_JSON" EXIT

echo "$output" | yq eval-all -o=json '[.]' > "$TEMP_JSON" 2>/dev/null

# Count resources
resource_count=$(jq 'length' "$TEMP_JSON")
echo "Found $resource_count resources to validate"
echo ""

# Process results
errors=0
warnings=0

# Process each resource
for i in $(seq 0 $((resource_count - 1))); do
    # Extract single document
    doc=$(jq -c ".[$i]" "$TEMP_JSON")
    
    # Get resource info
    kind=$(echo "$doc" | jq -r '.kind // "unknown"')
    name=$(echo "$doc" | jq -r '.metadata.name // "unnamed"')
    namespace=$(echo "$doc" | jq -r '.metadata.namespace // "default"')
    
    # Skip non-Kubernetes resources
    if [ "$kind" = "unknown" ]; then
        continue
    fi
    
    echo "[$((i+1))/$resource_count] Validating: $namespace/$kind/$name"
    
    # Run OPA evaluation
    result=$(opa eval -d "$POLICY_FILE" -I "$doc" "data.kubernetes.validation" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "  ${RED}ERROR${NC}: OPA evaluation failed"
        echo "  $result"
        ((errors++))
        continue
    fi
    
    # Extract the validation result
    validation=$(echo "$result" | jq -r '.result[0].expressions[0].value' 2>/dev/null || echo '{}')
    
    # Check deny rules
    denials=$(echo "$validation" | jq -r '.deny[]?' 2>/dev/null || true)
    if [ -n "$denials" ]; then
        while IFS= read -r denial; do
            echo -e "  ${RED}DENY${NC}: $denial"
            ((errors++))
        done <<< "$denials"
    fi
    
    # Check warn rules
    warns=$(echo "$validation" | jq -r '.warn[]?' 2>/dev/null || true)
    if [ -n "$warns" ]; then
        while IFS= read -r warning; do
            echo -e "  ${YELLOW}WARN${NC}: $warning"
            ((warnings++))
        done <<< "$warns"
    fi
done

echo ""
echo "=== Validation Summary ==="
echo "Errors: ${errors}"
echo "Warnings: ${warnings}"

if [ $errors -gt 0 ]; then
    echo -e "${RED}✗ Validation failed${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Validation passed${NC}"
fi