#!/bin/bash

# Simple log monitoring script
MYSTIC_PATH=${MYSTIC_PATH:-/mystic}

if [ -f "$MYSTIC_PATH/logs/server.log" ]; then
    tail -f "$MYSTIC_PATH/logs/server.log"
else
    echo "No server log found yet..."
    sleep 5
    exec "$0"
fi