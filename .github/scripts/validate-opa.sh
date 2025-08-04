#!/usr/bin/env bash
set -euo pipefail

# Parse arguments
KUBERNETES_DIR="./kubernetes"
POLICY_FILE=".github/policies/kubernetes.rego"
SPECIFIC_DIRS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --kubernetes-dir)
            KUBERNETES_DIR="$2"
            shift 2
            ;;
        --policy)
            POLICY_FILE="$2"
            shift 2
            ;;
        --dirs)
            SPECIFIC_DIRS="$2"
            shift 2
            ;;
        *)
            # Legacy support: first arg is kubernetes dir, second is policy file
            if [ -z "$KUBERNETES_DIR" ] && [ -d "$1" ]; then
                KUBERNETES_DIR="$1"
            elif [ -z "$POLICY_FILE" ] && [ -f "$1" ]; then
                POLICY_FILE="$1"
            fi
            shift
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Global counters
total_errors=0
total_warnings=0

# Check if OPA is installed
if ! command -v opa &> /dev/null; then
    echo -e "${RED}ERROR${NC}: OPA not installed. Install with: brew install opa"
    exit 1
fi

echo "=== Running OPA Policy Validation ==="
echo "Policy: ${POLICY_FILE}"
echo ""

# Function to validate a single resource
validate_resource() {
    local doc="$1"
    local source="$2"
    local errors=0
    local warnings=0

    # Get resource info
    local kind=$(echo "$doc" | jq -r '.kind // "unknown"')
    local name=$(echo "$doc" | jq -r '.metadata.name // "unnamed"')
    local namespace=$(echo "$doc" | jq -r '.metadata.namespace // "default"')

    # Skip non-Kubernetes resources
    if [ "$kind" = "unknown" ]; then
        return
    fi

    # Run OPA evaluation
    local result=$(opa eval -d "$POLICY_FILE" -I "$doc" "data.kubernetes.validation" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "  ${RED}ERROR${NC}: Failed to evaluate $namespace/$kind/$name"
        ((total_errors++))
        return
    fi

    # Extract the validation result
    local validation=$(echo "$result" | jq -r '.result[0].expressions[0].value' 2>/dev/null || echo '{}')

    # Check deny rules
    local denials=$(echo "$validation" | jq -r '.deny[]?' 2>/dev/null || true)
    if [ -n "$denials" ]; then
        while IFS= read -r denial; do
            echo -e "  ${RED}DENY${NC} [$source] $namespace/$kind/$name: $denial"
            ((total_errors++))
        done <<< "$denials"
    fi

    # Check warn rules
    local warns=$(echo "$validation" | jq -r '.warn[]?' 2>/dev/null || true)
    if [ -n "$warns" ]; then
        while IFS= read -r warning; do
            echo -e "  ${YELLOW}WARN${NC} [$source] $namespace/$kind/$name: $warning"
            ((total_warnings++))
        done <<< "$warns"
    fi
}

# Process kustomizations
echo "Processing Kustomizations..."

# Determine which directories to process
if [ -n "$SPECIFIC_DIRS" ]; then
    # Process only specific directories
    echo "Processing specific directories: $SPECIFIC_DIRS"
    for dir in $SPECIFIC_DIRS; do
        # Ensure the directory exists and has a kustomization.yaml
        if [ -f "$dir/kustomization.yaml" ]; then
            relative_dir="${dir#${KUBERNETES_DIR}/}"
            
            # Build the kustomization
            if output=$(kustomize build "$dir" --load-restrictor=LoadRestrictionsNone 2>&1); then
                # Convert to JSON array
                json_docs=$(echo "$output" | yq eval-all -o=json '[.]' 2>/dev/null)
                
                # Count resources
                resource_count=$(echo "$json_docs" | jq 'length' 2>/dev/null || echo "0")
                
                if [ "$resource_count" -gt 0 ]; then
                    # Process each resource
                    for i in $(seq 0 $((resource_count - 1))); do
                        doc=$(echo "$json_docs" | jq -c ".[$i]")
                        validate_resource "$doc" "$relative_dir"
                    done
                fi
            else
                echo -e "  ${YELLOW}WARN${NC}: Failed to build kustomization"
                echo -e "  ${YELLOW}     ${NC}$(echo "$output" | head -1)"
            fi
        fi
    done
else
    # Process all kustomizations (original behavior)
    find "${KUBERNETES_DIR}/apps" -type f -name "kustomization.yaml" \
        -not -path "*/components/*" | sort | while read -r kustomization; do

        dir="${kustomization%/kustomization.yaml}"
        relative_dir="${dir#${KUBERNETES_DIR}/}"

    # Build the kustomization
    if output=$(kustomize build "$dir" --load-restrictor=LoadRestrictionsNone 2>&1); then
        # Convert to JSON array
        json_docs=$(echo "$output" | yq eval-all -o=json '[.]' 2>/dev/null)

        # Count resources
        resource_count=$(echo "$json_docs" | jq 'length' 2>/dev/null || echo "0")

        if [ "$resource_count" -gt 0 ]; then
            # Process each resource
            for i in $(seq 0 $((resource_count - 1))); do
                doc=$(echo "$json_docs" | jq -c ".[$i]")
                validate_resource "$doc" "$relative_dir"
            done
        fi
    else
        echo -e "  ${YELLOW}WARN${NC}: Failed to build kustomization"
        echo -e "  ${YELLOW}     ${NC}$(echo "$output" | head -1)"
    fi
done
fi

# Process HelmReleases (just validate the HelmRelease object itself for now)
echo "Processing HelmReleases..."

if [ -n "$SPECIFIC_DIRS" ]; then
    # Process HelmReleases only in specific directories
    for dir in $SPECIFIC_DIRS; do
        if [ -f "$dir/helmrelease.yaml" ]; then
            helmrelease="$dir/helmrelease.yaml"
            relative_path="${helmrelease#${KUBERNETES_DIR}/}"
            
            # Process the HelmRelease file
            if json_docs=$(yq eval-all -o=json '[.]' "$helmrelease" 2>/dev/null); then
                resource_count=$(echo "$json_docs" | jq 'length' 2>/dev/null || echo "0")
                
                if [ "$resource_count" -gt 0 ]; then
                    for i in $(seq 0 $((resource_count - 1))); do
                        doc=$(echo "$json_docs" | jq -c ".[$i]")
                        validate_resource "$doc" "$relative_path"
                    done
                fi
            fi
        fi
    done
else
    # Process all HelmReleases
    find "${KUBERNETES_DIR}/apps" -type f -name "helmrelease.yaml" | sort | while read -r helmrelease; do
        relative_path="${helmrelease#${KUBERNETES_DIR}/}"

        # Process the HelmRelease file
        if json_docs=$(yq eval-all -o=json '[.]' "$helmrelease" 2>/dev/null); then
            resource_count=$(echo "$json_docs" | jq 'length' 2>/dev/null || echo "0")

            if [ "$resource_count" -gt 0 ]; then
                for i in $(seq 0 $((resource_count - 1))); do
                    doc=$(echo "$json_docs" | jq -c ".[$i]")
                    validate_resource "$doc" "$relative_path"
                done
            fi
        fi
    done
fi

# Process standalone YAML files in flux directories
if [ -z "$SPECIFIC_DIRS" ]; then
    echo "Processing Flux resources..."
    find "${KUBERNETES_DIR}/flux" -type f \( -name "*.yaml" -o -name "*.yml" \) \
    -not -name "*.sops.yaml" \
    -not -name "kustomization.yaml" | sort | while read -r file; do

    relative_path="${file#${KUBERNETES_DIR}/}"

    # Skip if file is empty or only contains comments
    if ! grep -q -v -E '^\s*(#|$)' "$file"; then
        continue
    fi

    # Process the file
    if json_docs=$(yq eval-all -o=json '[.]' "$file" 2>/dev/null); then
        resource_count=$(echo "$json_docs" | jq 'length' 2>/dev/null || echo "0")

        if [ "$resource_count" -gt 0 ]; then
            for i in $(seq 0 $((resource_count - 1))); do
                doc=$(echo "$json_docs" | jq -c ".[$i]")
                validate_resource "$doc" "$relative_path"
            done
        fi
    fi
done
fi

echo "=== OPA Validation Summary ==="
echo "Total Errors: ${total_errors}"
echo "Total Warnings: ${total_warnings}"

if [ $total_errors -gt 0 ]; then
    echo -e "${RED}✗ Validation failed with $total_errors errors${NC}"
    exit 1
else
    echo -e "${GREEN}✓ Validation passed${NC}"
fi
