#!/bin/bash
# Entrypoint script for GraphDB on Railway

set -e

echo "🚂 Starting GraphDB on Railway..."

# Start GraphDB in daemon mode
echo "Starting GraphDB server in daemon mode..."
/opt/graphdb/dist/bin/graphdb -d -s -Dgraphdb.home=/opt/graphdb/home

# Wait longer for GraphDB to start - it can take 60+ seconds
echo "Waiting 60 seconds for GraphDB to fully initialize..."
sleep 60

# Check if GraphDB process is running
if pgrep -f "graphdb" > /dev/null; then
    echo "✅ GraphDB process is running"
else
    echo "❌ GraphDB process is not running!"
    echo "Checking logs..."
    if [ -f /opt/graphdb/home/logs/main.log ]; then
        tail -n 50 /opt/graphdb/home/logs/main.log
    fi
    exit 1
fi

# Test if GraphDB REST API is responding
echo "Testing GraphDB REST API connectivity..."
if curl -sf http://localhost:7200/rest/repositories > /dev/null 2>&1; then
    echo "✅ GraphDB REST API is responding"
else
    echo "⚠️ GraphDB REST API not yet ready, waiting another 30 seconds..."
    sleep 30
fi

# Run initialization script
echo "Running data initialization..."
/opt/graphdb/init-graphdb.sh

# Keep container running by tailing the log
echo "GraphDB is running. Tailing logs..."
tail -f /opt/graphdb/home/logs/main.log

