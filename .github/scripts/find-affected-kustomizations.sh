#!/usr/bin/env bash
set -euo pipefail

# Script to find kustomization directories affected by changed files
# Usage: find-affected-kustomizations.sh "file1 file2 file3..."

CHANGED_FILES="${1:-}"
KUBERNETES_DIR="${2:-./kubernetes}"

# If no files provided, exit early
if [ -z "$CHANGED_FILES" ]; then
    echo "No changed files provided" >&2
    exit 0
fi

# Convert space-separated list to array
IFS=' ' read -ra files <<< "$CHANGED_FILES"

# Track unique affected kustomizations
declare -A affected_kustomizations
declare -A affected_flux_kustomizations

# Function to find parent kustomization.yaml
find_parent_kustomization() {
    local file="$1"
    local dir=$(dirname "$file")
    
    # Walk up the directory tree looking for kustomization.yaml
    while [[ "$dir" != "." && "$dir" != "/" && "$dir" == *"kubernetes"* ]]; do
        if [ -f "$dir/kustomization.yaml" ]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    return 1
}

# Function to find Flux Kustomization that references a path
find_flux_kustomization() {
    local target_path="$1"
    local relative_path="${target_path#${KUBERNETES_DIR}/}"
    
    # Search for ks.yaml files that reference this path
    find "${KUBERNETES_DIR}" -name "ks.yaml" -type f | while read -r ks_file; do
        # Check if this ks.yaml references our path
        if grep -q "path:.*${relative_path}" "$ks_file" 2>/dev/null; then
            echo "$ks_file"
        fi
    done
}

# Process each changed file
for file in "${files[@]}"; do
    # Skip non-kubernetes files
    if [[ ! "$file" =~ ^kubernetes/ ]]; then
        continue
    fi
    
    # Skip non-YAML files
    if [[ ! "$file" =~ \.(yaml|yml)$ ]]; then
        continue
    fi
    
    # For files in apps directory
    if [[ "$file" =~ ^kubernetes/apps/ ]]; then
        # Find parent kustomization
        if parent_kustomization=$(find_parent_kustomization "$file"); then
            affected_kustomizations["$parent_kustomization"]=1
            
            # Also find any Flux Kustomization that references this
            flux_refs=$(find_flux_kustomization "$parent_kustomization")
            if [ -n "$flux_refs" ]; then
                while IFS= read -r flux_ref; do
                    affected_flux_kustomizations["$(dirname "$flux_ref")"]=1
                done <<< "$flux_refs"
            fi
        fi
    fi
    
    # For files in flux directory
    if [[ "$file" =~ ^kubernetes/flux/ ]]; then
        # If it's a ks.yaml file, extract the path it references
        if [[ "$file" =~ ks\.yaml$ ]]; then
            referenced_path=$(yq eval '.spec.path' "$file" 2>/dev/null | sed 's|^./||')
            if [ -n "$referenced_path" ] && [ "$referenced_path" != "null" ]; then
                # Convert relative path to absolute
                if [[ "$referenced_path" =~ ^kubernetes/ ]]; then
                    affected_kustomizations["$referenced_path"]=1
                fi
            fi
        fi
        
        # Always include the directory containing the changed flux file
        dir=$(dirname "$file")
        if [ -f "$dir/kustomization.yaml" ]; then
            affected_kustomizations["$dir"]=1
        fi
    fi
done

# Output affected kustomization directories
{
    for kustomization in "${!affected_kustomizations[@]}"; do
        echo "$kustomization"
    done
    for flux_kustomization in "${!affected_flux_kustomizations[@]}"; do
        echo "$flux_kustomization"
    done
} | sort -u | tr '\n' ' ' | sed 's/ $//'