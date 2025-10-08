#!/bin/bash

# Simple log monitoring script
if [ -f "/mystic/logs/server.log" ]; then
    tail -f /mystic/logs/server.log
else
    echo "No server log found yet..."
    sleep 5
    exec "$0"
fi