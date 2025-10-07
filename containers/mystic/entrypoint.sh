#!/bin/bash

# Mystic BBS container boot script

# cleanup procedure
cleanup() {
    echo "Shutting down Mystic BBS..."
    if [ -f "/mystic/mis" ]; then
        /mystic/mis shutdown
    fi
    exit 0
}

# trap SIGTERM for graceful shutdown
trap 'cleanup' SIGTERM

# Start cron for logrotate
echo "Starting cron..."
service cron start

# Check if Mystic BBS exists in persistent storage, if not copy from image
if [ ! -f "/mystic/mis" ]; then
    echo "Copying Mystic BBS to persistent storage..."
    cp -r /opt/mystic/* /mystic/
    chown -R mystic:mystic /mystic
fi

# Verify cryptlib
echo "Checking cryptlib installation..."
ldconfig -p | grep libcl && echo "Cryptlib is available for SSH support" || echo "Warning: cryptlib not found"

cd /mystic

# Start Mystic BBS
echo "Starting Mystic BBS server..."
echo "Note: Mystic BBS will handle SSH on port 22 with cryptlib support"
echo "Configure SSH server in Mystic configuration: System > Configuration > Servers"

# Start logger in background
/mystic/tailit.sh &

# Start Mystic BBS server
./mis server &

# Keep container alive
tail -f /dev/null