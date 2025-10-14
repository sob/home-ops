#!/bin/bash
# Mystic BBS Door Installer
#
# This script helps install popular DOS doors for Mystic BBS
# Usage: install-door.sh [door_name] or install-door.sh list

set -e

# Configuration
DOORS_ROOT=${DOORS_ROOT:-/doors/dosemu/drive_c/doors}
TEMP_DIR=$(mktemp -d)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Cleanup on exit
trap 'rm -rf "$TEMP_DIR"' EXIT

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Door catalog - Add more doors here
# Format: name|description|url|archive_type|extract_dir|nested_archives (optional, comma-separated)
declare -A DOOR_CATALOG=(
    ["lord"]="Legend of the Red Dragon|http://breakintochat.com/files/doors/Robinson/LORD/distributions/lord407.zip|zip|lord|LORD.ZIP"
    ["tw2002"]="Trade Wars 2002|http://breakintochat.com/files/doors/Martech/TW2002/distributions/2002V309-DPMI.ZIP|zip|tw2002"
    ["bre"]="Barren Realms Elite|http://breakintochat.com/files/doors/SRGames/BRE/distributions/bre0987.arj|arj|bre"
    ["teos"]="Planets: The Exploration of Space|http://breakintochat.com/files/doors/Robinson/planets-teos/distributions/teos201b.zip|zip|teos"
    ["usurper"]="Usurper|http://breakintochat.com/files/doors/Dangarden/Usurper/distributions/USURP019B6.ZIP|zip|usurper"
    ["sre"]="Solar Realms Elite|http://breakintochat.com/files/doors/SRGames/SRE/distributions/sre0994b.arj|arj|sre"
    ["darkness"]="Darkness|https://jackphla.sh/files/darkness/DRK200.ZIP|zip|darkness"
    ["oo"]="Operation Overkill|https://operationoverkill.com/files/oo120.zip|zip|oo"
)

list_doors() {
    echo ""
    echo "Available Doors:"
    echo "================"
    echo ""

    for door in "${!DOOR_CATALOG[@]}"; do
        IFS='|' read -r desc url type dir <<< "${DOOR_CATALOG[$door]}"
        printf "  %-12s - %s\n" "$door" "$desc"
    done

    echo ""
    echo "Usage: install-door.sh [door_name]"
    echo "Example: install-door.sh lord"
    echo ""
}

download_door() {
    local url=$1
    local output=$2

    log_info "Downloading from: $url"

    if command -v wget &> /dev/null; then
        wget -q --show-progress -O "$output" "$url" || {
            log_error "Download failed"
            return 1
        }
    elif command -v curl &> /dev/null; then
        curl -L -o "$output" "$url" || {
            log_error "Download failed"
            return 1
        }
    else
        log_error "Neither wget nor curl is available"
        return 1
    fi
}

extract_archive() {
    local archive=$1
    local type=$2
    local dest=$3

    log_info "Extracting archive..."

    mkdir -p "$dest"

    case "$type" in
        zip)
            if command -v unzip &> /dev/null; then
                unzip -q -o "$archive" -d "$dest" || {
                    log_error "Extraction failed"
                    return 1
                }
            else
                log_error "unzip is not available"
                return 1
            fi
            ;;
        arj)
            if command -v arj &> /dev/null; then
                cd "$dest" && arj x -y "$archive" || {
                    log_error "Extraction failed"
                    return 1
                }
            elif command -v unarj &> /dev/null; then
                cd "$dest" && unarj x "$archive" || {
                    log_error "Extraction failed"
                    return 1
                }
            else
                log_error "arj/unarj is not available"
                return 1
            fi
            ;;
        rar)
            if command -v unrar &> /dev/null; then
                unrar x -o+ "$archive" "$dest/" || {
                    log_error "Extraction failed"
                    return 1
                }
            else
                log_error "unrar is not available"
                return 1
            fi
            ;;
        tar.gz|tgz)
            tar -xzf "$archive" -C "$dest" || {
                log_error "Extraction failed"
                return 1
            }
            ;;
        *)
            log_error "Unknown archive type: $type"
            return 1
            ;;
    esac
}

extract_nested_archives() {
    local dir=$1
    local specific_archives=$2  # Optional: comma-separated list of specific archives to extract

    if [ -z "$specific_archives" ]; then
        log_info "No nested archives specified for this door"
        return 0
    fi

    log_info "Extracting nested archives: $specific_archives"

    # Split comma-separated list and process each archive
    IFS=',' read -ra ARCHIVES <<< "$specific_archives"
    for archive_pattern in "${ARCHIVES[@]}"; do
        # Trim whitespace
        archive_pattern=$(echo "$archive_pattern" | xargs)

        # Find matching archive (case-insensitive)
        local found_archive=$(find "$dir" -maxdepth 1 -type f -iname "$archive_pattern" 2>/dev/null | head -1)

        if [ -z "$found_archive" ]; then
            log_warn "Nested archive not found: $archive_pattern"
            continue
        fi

        local archive_name=$(basename "$found_archive")
        local archive_ext="${archive_name##*.}"
        archive_ext=$(echo "$archive_ext" | tr '[:upper:]' '[:lower:]')

        log_info "Extracting nested archive: $archive_name"

        # Extract in place
        case "$archive_ext" in
            zip)
                if command -v unzip &> /dev/null; then
                    unzip -q -o "$found_archive" -d "$dir" && rm "$found_archive"
                else
                    log_error "unzip not available, skipping $archive_name"
                fi
                ;;
            arj)
                if command -v arj &> /dev/null; then
                    (cd "$dir" && arj x -y "$found_archive" && rm "$found_archive")
                elif command -v unarj &> /dev/null; then
                    (cd "$dir" && unarj x "$found_archive" && rm "$found_archive")
                else
                    log_error "arj/unarj not available, skipping $archive_name"
                fi
                ;;
            rar)
                if command -v unrar &> /dev/null; then
                    unrar x -o+ "$found_archive" "$dir/" && rm "$found_archive"
                else
                    log_error "unrar not available, skipping $archive_name"
                fi
                ;;
            *)
                log_warn "Unknown nested archive type: $archive_ext"
                ;;
        esac
    done
}

install_door() {
    local door_name=$1

    # Check if door exists in catalog
    if [[ ! -v "DOOR_CATALOG[$door_name]" ]]; then
        log_error "Unknown door: $door_name"
        echo ""
        list_doors
        exit 1
    fi

    # Parse door info
    IFS='|' read -r desc url type extract_dir nested_archives <<< "${DOOR_CATALOG[$door_name]}"

    log_info "Installing: $desc"

    # Check if already installed
    local install_path="$DOORS_ROOT/$extract_dir"
    if [ -d "$install_path" ]; then
        log_warn "Door directory already exists: $install_path"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
        rm -rf "$install_path"
    fi

    # Download
    local archive="$TEMP_DIR/door_archive"
    download_door "$url" "$archive" || exit 1

    # Extract
    extract_archive "$archive" "$type" "$install_path" || exit 1

    # Extract any nested archives (e.g., LORD.ZIP inside lord407.zip)
    if [ -n "$nested_archives" ]; then
        extract_nested_archives "$install_path" "$nested_archives"
    fi

    # Convert text files to Unix format if dos2unix is available
    if command -v dos2unix &> /dev/null; then
        log_info "Converting text files..."
        find "$install_path" -type f \( -name "*.txt" -o -name "*.cfg" -o -name "*.bat" \) \
            -exec dos2unix {} \; 2>/dev/null || true
    fi

    # Set permissions
    log_info "Setting permissions..."
    find "$install_path" -type f -name "*.exe" -exec chmod +x {} \; 2>/dev/null || true
    find "$install_path" -type f -name "*.bat" -exec chmod +x {} \; 2>/dev/null || true

    log_info "Installation complete!"
    log_info "Door installed to: $install_path"
    echo ""
    log_info "Next steps:"
    echo "  1. Configure the door in Mystic BBS (System > Configuration > Doors)"
    echo "  2. Set the door command to: /usr/local/bin/rundoor.sh %N $door_name"
    echo "  3. Set dropfile type to DOOR.SYS"
    echo ""

    # Show any README files
    local readme_files=$(find "$install_path" -maxdepth 1 -iname "readme*" -o -iname "*.doc" 2>/dev/null | head -5)
    if [ -n "$readme_files" ]; then
        log_info "Documentation found:"
        echo "$readme_files" | while read -r file; do
            echo "  - $(basename "$file")"
        done
        echo ""
    fi
}

# Main
if [ $# -eq 0 ] || [ "$1" = "list" ]; then
    list_doors
    exit 0
fi

DOOR_NAME=$(echo "$1" | tr '[:upper:]' '[:lower:]')
install_door "$DOOR_NAME"
