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

# Start cron for logrotate
echo "Starting cron..."
service cron start

# Check if Mystic BBS exists in persistent storage, if not run installer
if [ ! -f "$MYSTIC_PATH/mis" ]; then
    echo "Installing Mystic BBS to $MYSTIC_PATH..."
    mkdir -p "$MYSTIC_PATH"
    
    # Run pre-install hook
    run_hook "pre-install.sh"
    
    # Run the installer
    cd "$MYSTIC_PATH"
    /usr/local/bin/mystic-install auto .
    
    # Run post-install hook
    run_hook "post-install.sh"
    
    echo "Mystic BBS installation completed"
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
$MYSTIC_PATH/tailit.sh &

# Start Mystic BBS server
./mis server &

# Keep container alive
tail -f /dev/null