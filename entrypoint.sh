#!/bin/bash
# Entrypoint script for GraphDB on Railway

set -e

echo "🚂 Starting GraphDB on Railway..."

# Start GraphDB in daemon mode
echo "Starting GraphDB server..."
/opt/graphdb/dist/bin/graphdb -d -s -Dgraphdb.home=/opt/graphdb/home

# Wait a bit for GraphDB to start
sleep 10

# Run initialization script
echo "Running initialization..."
/opt/graphdb/init-graphdb.sh

# Keep container running by tailing the log
echo "GraphDB is running. Tailing logs..."
tail -f /opt/graphdb/home/logs/main.log