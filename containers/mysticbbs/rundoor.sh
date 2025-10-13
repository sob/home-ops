#!/bin/bash
# Mystic BBS Door Launcher for DOS doors via dosemu2
#
# Usage: rundoor.sh <node_number> <door_name> [doorfile_type]
#
# Arguments:
#   node_number    - Node number (1-N)
#   door_name      - Door identifier (lowercase, matches door config)
#   doorfile_type  - Optional: 1=DOOR.SYS (default), 2=CHAIN.TXT
#
# Environment variables:
#   MYSTIC_PATH    - Path to Mystic BBS installation (default: /config)
#   DOSEMU_ROOT    - Path to dosemu root (default: /doors/dosemu)
#   DOORS_PATH     - Path to doors directory (default: /doors)
#   DOOR_CONFIG    - Path to door configuration file (default: /doors/doors.conf)

set -e

# Trap SIGINT to prevent Ctrl+C from killing the script prematurely
trap '' 2

# Parse arguments
NODE=${1:?Node number is required}
DOOR=${2:?Door name is required}
DOORFILE_TYPE=${3:-1}

# Set default paths from environment or use defaults
MYSTIC_PATH=${MYSTIC_PATH:-/config}
DOSEMU_ROOT=${DOSEMU_ROOT:-/doors/dosemu}
DOORS_PATH=${DOORS_PATH:-/doors}
DOOR_CONFIG=${DOOR_CONFIG:-/doors/doors.conf}

# Ensure door name is lowercase
DOOR=$(echo "$DOOR" | tr '[:upper:]' '[:lower:]')

# Mystic node temporary directory
NODE_DIR="$MYSTIC_PATH/temp$NODE"
DOORFILE="$NODE_DIR/DOOR.SYS"

# dosemu node directory
DOSEMU_NODE_DIR="$DOSEMU_ROOT/drive_c/nodes/temp$NODE"

# Check if dosemu is available
if ! command -v dosemu &> /dev/null; then
    echo "ERROR: dosemu2 is not installed or not in PATH"
    echo "DOS doors are not available on this architecture"
    exit 1
fi

# Check if node directory exists
if [ ! -d "$NODE_DIR" ]; then
    echo "ERROR: Node directory does not exist: $NODE_DIR"
    exit 1
fi

# Check if DOOR.SYS exists
if [ ! -f "$DOORFILE" ]; then
    echo "ERROR: DOOR.SYS not found: $DOORFILE"
    exit 1
fi

# Set terminal size for DOS applications
stty cols 80 rows 25 2>/dev/null || true

# Get username from DOOR.SYS (line 36 for DOOR.SYS format)
USERNAME=$(sed -n '36p' "$DOORFILE" 2>/dev/null || echo "Unknown")

echo "Door Launch: User=$USERNAME, Node=$NODE, Door=$DOOR"

# Create dosemu node directory if it doesn't exist
mkdir -p "$DOSEMU_NODE_DIR"

# Convert DOOR.SYS to DOS line endings and copy to dosemu directory
unix2dos < "$DOORFILE" > "$DOSEMU_NODE_DIR/DOOR.SYS" 2>/dev/null

# Generate random 4-digit hex code for batch file uniqueness
RAND=$(tr -dc 'a-f0-9' < /dev/urandom 2>/dev/null | head -c 4)
BATCH_FILE="RUN$RAND.BAT"
BATCH_PATH="$DOSEMU_NODE_DIR/$BATCH_FILE"

# Function to cleanup after door execution
cleanup_door() {
    local node=$1
    local batch=$2
    local dosemu_dir=$3

    # Remove batch file and DOOR.SYS
    rm -f "$dosemu_dir/$batch" 2>/dev/null || true
    rm -f "$dosemu_dir/DOOR.SYS" 2>/dev/null || true

    # Copy any door output files back to Mystic temp directory
    # (some doors create DORINFO, RESULT.SYS, etc.)
    for file in "$dosemu_dir"/*.SYS "$dosemu_dir"/*.BAT; do
        if [ -f "$file" ] && [ "$(basename "$file")" != "$batch" ]; then
            dos2unix < "$file" > "$NODE_DIR/$(basename "$file")" 2>/dev/null || true
        fi
    done
}

# Function to run a batch file via dosemu
run_dosemu_batch() {
    local node=$1
    local batch=$2
    local dosemu_dir=$3

    # Run dosemu with the batch file
    # Redirect stderr to avoid noise, stdout is visible to user
    dosemu -E "C:\\NODES\\TEMP$node\\$batch" 2>/dev/null || {
        echo "WARNING: dosemu exited with non-zero status"
    }

    # Cleanup
    cleanup_door "$node" "$batch" "$dosemu_dir"
}

# Load door configuration if it exists
declare -A DOOR_CMD
declare -A DOOR_PATH
declare -A DOOR_DESC

if [ -f "$DOOR_CONFIG" ]; then
    # Source the configuration file
    # Expected format:
    # DOOR_CMD[doorname]="DOOREXE.EXE /PARAMS"
    # DOOR_PATH[doorname]="C:\\DOORS\\DOORNAME"
    # DOOR_DESC[doorname]="Door Description"
    source "$DOOR_CONFIG"
fi

# Check if door is configured
if [ -z "${DOOR_CMD[$DOOR]}" ]; then
    echo "ERROR: Door '$DOOR' is not configured"
    echo "Please add door configuration to: $DOOR_CONFIG"
    exit 1
fi

# Get door configuration
CMD="${DOOR_CMD[$DOOR]}"
PATH_DIR="${DOOR_PATH[$DOOR]}"
DESC="${DOOR_DESC[$DOOR]:-$DOOR}"

echo "Launching: $DESC"
echo "Path: $PATH_DIR"
echo "Command: $CMD"

# Create the batch file
cat > "$BATCH_PATH" << EOF
@ECHO OFF
C:
CD $PATH_DIR
$CMD
IF ERRORLEVEL 1 PAUSE
EXIT
EOF

# Convert batch file to DOS format
unix2dos "$BATCH_PATH" 2>/dev/null

# Run the door
echo "Starting door execution..."
run_dosemu_batch "$NODE" "$BATCH_FILE" "$DOSEMU_NODE_DIR"

echo "Door execution completed"
exit 0
