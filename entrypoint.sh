#!/bin/bash
# Railway entrypoint: start GraphDB, wait until it is reachable, then init repo+data

set -euo pipefail

PORT_TO_USE="${PORT:-7200}"
GRAPHDB_URL="http://localhost:${PORT_TO_USE}"

echo "🚂 Starting GraphDB on Railway..."
echo "PORT: ${PORT_TO_USE}"
echo "GRAPHDB_URL (internal): ${GRAPHDB_URL}"

# (Recommended) keep heap conservative on small Railway instances
# You can adjust if your Railway RAM is larger.
export JAVA_OPTS="${JAVA_OPTS:--Xms256m -Xmx768m}"

echo "Starting GraphDB server in daemon mode..."

# Start GraphDB and force it to bind to Railway's PORT
/opt/graphdb/dist/bin/graphdb -d -s \
  -Dgraphdb.connector.port="${PORT_TO_USE}" \
  -Dgraphdb.home=/opt/graphdb/home

echo "⏳ Waiting for GraphDB REST API to be ready..."

MAX_RETRIES=90
RETRY=0

until curl -sS "${GRAPHDB_URL}/rest/repositories" >/dev/null; do
  RETRY=$((RETRY + 1))
  echo "  Attempt ${RETRY}/${MAX_RETRIES}: GraphDB not ready yet..."
  if [ "${RETRY}" -ge "${MAX_RETRIES}" ]; then
    echo "❌ GraphDB did not become ready in time."
    echo "---- Tail GraphDB logs ----"
    if [ -f /opt/graphdb/home/logs/main.log ]; then
      tail -n 300 /opt/graphdb/home/logs/main.log || true
    else
      echo "(main.log not found)"
      find /opt/graphdb -maxdepth 4 -type f -name "*.log" 2>/dev/null | head -n 20 || true
    fi
    exit 1
  fi
  sleep 5
done

echo "✅ GraphDB REST API is responding!"

echo "Running data initialization..."
/opt/graphdb/init-graphdb.sh

echo "✅ Initialization finished. Keeping container alive (tail logs)..."
if [ -f /opt/graphdb/home/logs/main.log ]; then
  tail -f /opt/graphdb/home/logs/main.log
else
  # fallback: keep alive even if log path differs
  tail -f /dev/null
fi
