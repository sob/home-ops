#!/bin/bash

# Mystic BBS container boot script

# Set default Mystic path if not provided
MYSTIC_PATH=${MYSTIC_PATH:-/mystic}

# Hook execution function
run_hook() {
    local hook_name="$1"
    local hook_path="$MYSTIC_PATH/hooks/$hook_name"
    
    if [ -f "$hook_path" ] && [ -x "$hook_path" ]; then
        echo "Running hook: $hook_name"
        "$hook_path"
        echo "Hook $hook_name completed"
    fi
}

# cleanup procedure
cleanup() {
    echo "Shutting down Mystic BBS..."
    
    # Run shutdown hook
    run_hook "shutdown.sh"
    
    if [ -f "$MYSTIC_PATH/mis" ]; then
        $MYSTIC_PATH/mis shutdown
    fi
    exit 0
}

# trap SIGTERM for graceful shutdown
trap 'cleanup' SIGTERM

# Start cron for logrotate (may fail with read-only filesystem, non-critical)
echo "Starting cron..."
service cron start 2>/dev/null || echo "Cron failed to start (non-critical)"

# Check if Mystic BBS exists in persistent storage
if [ ! -f "$MYSTIC_PATH/mis" ]; then
    mkdir -p "$MYSTIC_PATH"

    # Check if this is an upgrade (mystic.dat exists but mis doesn't)
    if [ -f "$MYSTIC_PATH/mystic.dat" ]; then
        echo "Existing Mystic BBS data detected - performing upgrade..."

        # Run pre-upgrade hook
        run_hook "pre-upgrade.sh"

        # Use the upgrade utility to preserve data files
        cd /usr/local/share/mystic
        ./upgrade "$MYSTIC_PATH"

        # Run post-upgrade hook
        run_hook "post-upgrade.sh"

        echo "Mystic BBS upgrade completed"
    else
        echo "Installing Mystic BBS to $MYSTIC_PATH..."

        # Run pre-install hook
        run_hook "pre-install.sh"

        # Run the installer (needs install_data.mys in same directory as installer)
        # Use 'overwrite' option to install into existing directory
        cd /usr/local/share/mystic
        ./install auto "$MYSTIC_PATH" overwrite

        # Run post-install hook
        run_hook "post-install.sh"

        echo "Mystic BBS installation completed"
    fi

    # Copy documentation files to config directory if they don't exist or differ
    for doc_file in whatsnew.txt upgrade.txt; do
        if [ -f "/usr/local/share/mystic/$doc_file" ]; then
            if [ ! -f "$MYSTIC_PATH/$doc_file" ] || ! cmp -s "/usr/local/share/mystic/$doc_file" "$MYSTIC_PATH/$doc_file"; then
                cp "/usr/local/share/mystic/$doc_file" "$MYSTIC_PATH/$doc_file" 2>/dev/null && \
                    echo "Updated $doc_file in $MYSTIC_PATH" || \
                    echo "Warning: Could not copy $doc_file (non-critical)"
            else
                echo "$doc_file is up to date"
            fi
        fi
    done
fi

# Verify cryptlib
echo "Checking cryptlib installation..."
ldconfig -p | grep libcl && echo "Cryptlib is available for SSH support" || echo "Warning: cryptlib not found"

cd "$MYSTIC_PATH"

# Run startup hook
run_hook "startup.sh"

# Start Mystic BBS
echo "Starting Mystic BBS server..."
echo "Note: Mystic BBS will handle SSH on port 22 with cryptlib support"
echo "Configure SSH server in Mystic configuration: System > Configuration > Servers"

# Start logger in background
/usr/local/bin/tailit.sh &

# Start Mystic BBS server
./mis server &

# Keep container alive
tail -f /dev/null