#!/bin/bash
# entrypoint.sh - Railway-safe GraphDB startup
# Forces GraphDB to bind to Railway's $PORT by editing graphdb.properties

set -euo pipefail

PORT_TO_USE="${PORT:-7200}"
GRAPHDB_URL="http://localhost:${PORT_TO_USE}"
GRAPHDB_HOME="${GRAPHDB_HOME:-/opt/graphdb/home}"
PROPS_FILE="${GRAPHDB_HOME}/conf/graphdb.properties"

echo "🚂 Starting GraphDB on Railway..."
echo "PORT_TO_USE: ${PORT_TO_USE}"
echo "GRAPHDB_HOME: ${GRAPHDB_HOME}"
echo "GRAPHDB_URL (internal): ${GRAPHDB_URL}"

# Safer heap defaults for small instances (override via Railway env if needed)
export JAVA_OPTS="${JAVA_OPTS:--Xms256m -Xmx768m}"
echo "JAVA_OPTS: ${JAVA_OPTS}"

# Ensure config file exists
if [ ! -f "${PROPS_FILE}" ]; then
  echo "❌ ERROR: graphdb.properties not found at ${PROPS_FILE}"
  echo "Listing ${GRAPHDB_HOME}/conf:"
  ls -la "${GRAPHDB_HOME}/conf" || true
  exit 1
fi

# Force GraphDB connector port to Railway PORT
echo "🔧 Setting graphdb.connector.port=${PORT_TO_USE} in ${PROPS_FILE}"

if grep -q '^graphdb\.connector\.port=' "${PROPS_FILE}"; then
  sed -i "s/^graphdb\.connector\.port=.*/graphdb.connector.port=${PORT_TO_USE}/" "${PROPS_FILE}"
else
  echo "graphdb.connector.port=${PORT_TO_USE}" >> "${PROPS_FILE}"
fi

echo "✅ Effective port line:"
grep '^graphdb\.connector\.port=' "${PROPS_FILE}" || true

echo "Starting GraphDB server in daemon mode..."
/opt/graphdb/dist/bin/graphdb -d -s -Dgraphdb.home="${GRAPHDB_HOME}"

echo "⏳ Waiting for GraphDB REST API..."
MAX_RETRIES=120
RETRY=0

until curl -sS "${GRAPHDB_URL}/rest/repositories" >/dev/null; do
  RETRY=$((RETRY+1))
  echo "  Attempt ${RETRY}/${MAX_RETRIES}: GraphDB not ready..."
  if [ "${RETRY}" -ge "${MAX_RETRIES}" ]; then
    echo "❌ GraphDB did not become ready in time."
    echo "---- Tail GraphDB logs ----"
    if [ -f "${GRAPHDB_HOME}/logs/main.log" ]; then
      tail -n 300 "${GRAPHDB_HOME}/logs/main.log" || true
    else
      echo "(main.log not found)"
      find "${GRAPHDB_HOME}" -maxdepth 4 -type f -name "*.log" 2>/dev/null | head -n 20 || true
    fi
    exit 1
  fi
  sleep 5
done

echo "✅ GraphDB REST API is responding at ${GRAPHDB_URL}"

echo "Running repository/data initialization..."
/opt/graphdb/init-graphdb.sh

echo "✅ Init done. Tailing logs..."
if [ -f "${GRAPHDB_HOME}/logs/main.log" ]; then
  tail -f "${GRAPHDB_HOME}/logs/main.log"
else
  tail -f /dev/null
fi
