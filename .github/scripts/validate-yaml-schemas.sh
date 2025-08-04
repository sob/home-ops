#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CACHE_DIR="${HOME}/.cache/yaml-schemas"

# Ensure cache directory exists
mkdir -p "$CACHE_DIR"

# Check if yajsv is installed
check_yajsv() {
    if ! command -v yajsv &> /dev/null; then
        echo -e "${YELLOW}yajsv is not installed.${NC}"
        echo -e "${YELLOW}Please install it with: go install github.com/neilpa/yajsv@latest${NC}"
        echo -e "${YELLOW}Then symlink: ln -sf ~/go/bin/yajsv /opt/homebrew/bin/yajsv${NC}"
        exit 1
    fi
}

# Extract schema URL from YAML file
extract_schema_url() {
    local file=$1
    grep -m1 "yaml-language-server:.*\$schema=" "$file" 2>/dev/null | sed -E 's/.*\$schema=([^ ]+).*/\1/' || true
}

# Download schema if not cached
download_schema() {
    local url=$1
    local cache_file="${CACHE_DIR}/$(echo "$url" | sed 's/[^a-zA-Z0-9]/_/g').json"
    
    if [ ! -f "$cache_file" ] || [ ! -s "$cache_file" ]; then
        # First check if the URL returns 404
        local http_code=$(curl -sL -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "$url")
        if [ "$http_code" = "404" ]; then
            echo -e "${YELLOW}Schema not found (404): $url${NC}" >&2
            echo -e "${YELLOW}Consider removing or updating the schema declaration${NC}" >&2
            return 1
        fi
        
        if ! curl -sL --connect-timeout 10 --max-time 30 "$url" -o "$cache_file.tmp"; then
            echo -e "${RED}Failed to download schema from: $url${NC}" >&2
            rm -f "$cache_file.tmp"
            return 1
        fi
        
        # Check if the downloaded file is valid JSON
        if ! jq empty "$cache_file.tmp" 2>/dev/null; then
            echo -e "${RED}Downloaded schema is not valid JSON: $url${NC}" >&2
            rm -f "$cache_file.tmp"
            return 1
        fi
        
        mv "$cache_file.tmp" "$cache_file"
    fi
    
    echo "$cache_file"
}

# Process a single file
process_file() {
    local file=$1
    local schema_url
    local schema_file
    
    schema_url=$(extract_schema_url "$file")
    
    if [ -z "$schema_url" ]; then
        return 0  # Skip files without schema
    fi
    
    # Show shorter path
    local short_path="${file#kubernetes/}"
    echo -n "  $short_path ... "
    
    # Download schema
    if ! schema_file=$(download_schema "$schema_url"); then
        echo -e "${RED}✗ (failed to download schema)${NC}"
        return 1
    fi
    
    # Run validation
    if yajsv -s "$schema_file" "$file" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        # Run again to show the error
        yajsv -s "$schema_file" "$file" 2>&1 | sed 's/^/  /'
        return 1
    fi
}

# Main function
main() {
    local files=()
    local failed=0
    local with_schema=0
    local total=0
    
    # Check yajsv is installed
    check_yajsv
    
    # Get list of files
    if [ $# -eq 0 ]; then
        # Find all YAML files in kubernetes directory
        while IFS= read -r -d '' file; do
            files+=("$file")
        done < <(find kubernetes -type f \( -name "*.yaml" -o -name "*.yml" \) \
            -not -path "*/schemas/*" \
            -not -path "*/resources/*" \
            -not -name "*.sops.yaml" \
            -not -name "*.sops.yml" \
            -print0)
    else
        files=("$@")
    fi
    
    total=${#files[@]}
    echo "Checking $total YAML files for schema declarations..."
    
    # Count files with schemas
    for file in "${files[@]}"; do
        schema_url=$(extract_schema_url "$file")
        if [ -n "$schema_url" ]; then
            with_schema=$((with_schema + 1))
        fi
    done
    
    if [ $with_schema -eq 0 ]; then
        echo "No files with schema declarations found."
        exit 0
    fi
    
    echo "Found $with_schema files with schema declarations"
    echo "Processing files..."
    echo
    
    # Process each file
    local processed=0
    for file in "${files[@]}"; do
        schema_url=$(extract_schema_url "$file")
        if [ -n "$schema_url" ]; then
            processed=$((processed + 1))
            if ! process_file "$file"; then
                failed=$((failed + 1))
            fi
        fi
    done
    
    echo
    if [ $failed -eq 0 ]; then
        echo -e "${GREEN}✓ All $with_schema files passed schema validation${NC}"
        exit 0
    else
        echo -e "${RED}✗ $failed file(s) failed schema validation${NC}"
        exit 1
    fi
}

# Clear schema cache if requested
if [ "${1:-}" = "--clear-cache" ]; then
    echo "Clearing schema cache..."
    rm -rf "$CACHE_DIR"
    mkdir -p "$CACHE_DIR"
    echo "Cache cleared."
    exit 0
fi

main "$@"