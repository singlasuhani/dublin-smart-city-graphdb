#!/bin/bash
# GraphDB Auto-Initialization Script for Railway
# Creates repository and loads RDF data automatically on container startup

set -euo pipefail

PORT_TO_USE="${PORT:-7200}"
GRAPHDB_URL="http://localhost:${PORT_TO_USE}"

# Choose repo name (can override via env var REPO_NAME)
REPO_NAME="${REPO_NAME:-city_facilities}"
REPO_URL="${GRAPHDB_URL}/repositories/${REPO_NAME}"

ONTOLOGY_FILE="/opt/graphdb/data/ontology/facilities.ttl"
AREAS_FILE="/opt/graphdb/data/graph_data/areas.ttl"
FACILITIES_FILE="/opt/graphdb/data/graph_data/facilities_data.ttl"

echo "============================================"
echo "🚂 Railway GraphDB Initialization"
echo "============================================"
echo "GRAPHDB_URL: ${GRAPHDB_URL}"
echo "REPO_NAME  : ${REPO_NAME}"
echo "============================================"

# Wait for GraphDB to be fully ready (extra safety)
echo "⏳ Waiting for GraphDB to start..."
MAX_RETRIES=90
RETRY_COUNT=0

until curl -sS "${GRAPHDB_URL}/rest/repositories" >/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "${RETRY_COUNT}" -gt "${MAX_RETRIES}" ]; then
    echo "❌ ERROR: GraphDB failed to start after ${MAX_RETRIES} attempts"
    echo "---- Tail GraphDB logs ----"
    if [ -f /opt/graphdb/home/logs/main.log ]; then
      tail -n 300 /opt/graphdb/home/logs/main.log || true
    else
      echo "(main.log not found)"
      find /opt/graphdb -maxdepth 4 -type f -name "*.log" 2>/dev/null | head -n 20 || true
    fi
    exit 1
  fi
  echo "  Attempt ${RETRY_COUNT}/${MAX_RETRIES}..."
  sleep 5
done

echo "✅ GraphDB is ready!"

# Check if repository already exists
echo "🔍 Checking if repository exists..."
if curl -sS "${GRAPHDB_URL}/rest/repositories" | grep -q "\"${REPO_NAME}\""; then
  echo "✅ Repository '${REPO_NAME}' already exists"
else
  echo "📦 Creating repository '${REPO_NAME}' (TTL config)..."

  # Minimal repo config (most compatible; avoids 500s from extra settings)
  cat > /tmp/repo-config.ttl <<EOF
@prefix rep: <http://www.openrdf.org/config/repository#> .
@prefix sr: <http://www.openrdf.org/config/repository/sail#> .
@prefix sail: <http://www.openrdf.org/config/sail#> .

[] a rep:Repository ;
   rep:repositoryID "${REPO_NAME}" ;
   rep:repositoryImpl [
      rep:repositoryType "graphdb:SailRepository" ;
      sr:sailImpl [
         sail:sailType "graphdb:Sail"
      ]
   ] .
EOF

  RESP_FILE="/tmp/create-repo-response.txt"
  HTTP_CODE=$(
    curl -sS -o "${RESP_FILE}" -w "%{http_code}" \
      -X POST "${GRAPHDB_URL}/rest/repositories" \
      -H "Content-Type: text/turtle" \
      --data-binary @/tmp/repo-config.ttl \
    || true
  )

  if [ "${HTTP_CODE}" != "201" ] && [ "${HTTP_CODE}" != "204" ] && [ "${HTTP_CODE}" != "200" ]; then
    echo "❌ Failed to create repository. HTTP: ${HTTP_CODE}"
    echo "---- Response body ----"
    cat "${RESP_FILE}" || true
    echo "-----------------------"
    echo "---- Tail GraphDB logs ----"
    if [ -f /opt/graphdb/home/logs/main.log ]; then
      tail -n 300 /opt/graphdb/home/logs/main.log || true
    fi
    echo "---------------------------"
    exit 1
  fi

  echo "✅ Repository created successfully (HTTP ${HTTP_CODE})"
fi

sleep 2

# Triple count (to avoid re-loading + duplicates on redeploy)
echo "============================================"
echo "📊 Checking current triple count..."
echo "============================================"

COUNT_BEFORE=$(
  curl -sS -G "${REPO_URL}" \
    --data-urlencode 'query=SELECT (COUNT(*) as ?count) WHERE { ?s ?p ?o }' \
    -H "Accept: application/sparql-results+json" \
  | grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0"
)

echo "📈 Current triples in '${REPO_NAME}': ${COUNT_BEFORE}"

if [ "${COUNT_BEFORE:-0}" -gt 0 ]; then
  echo "✅ Repository already has data. Skipping load to avoid duplicates."
else
  echo "============================================"
  echo "📚 Loading RDF Data Files..."
  echo "============================================"

  for f in "${ONTOLOGY_FILE}" "${AREAS_FILE}" "${FACILITIES_FILE}"; do
    if [ ! -f "${f}" ]; then
      echo "❌ Missing file: ${f}"
      exit 1
    fi
  done

  echo "1/3 Loading facilities ontology..."
  curl -f -sS -X POST "${REPO_URL}/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @"${ONTOLOGY_FILE}"
  echo "  ✅ Ontology loaded"

  echo "2/3 Loading committee areas..."
  curl -f -sS -X POST "${REPO_URL}/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @"${AREAS_FILE}"
  echo "  ✅ Areas loaded"

  echo "3/3 Loading facilities data..."
  curl -f -sS -X POST "${REPO_URL}/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @"${FACILITIES_FILE}"
  echo "  ✅ Facilities loaded"
fi

echo ""
echo "============================================"
echo "📊 Verification"
echo "============================================"

COUNT_AFTER=$(
  curl -sS -G "${REPO_URL}" \
    --data-urlencode 'query=SELECT (COUNT(*) as ?count) WHERE { ?s ?p ?o }' \
    -H "Accept: application/sparql-results+json" \
  | grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0"
)

echo "📈 Total triples in '${REPO_NAME}': ${COUNT_AFTER}"

if [ "${COUNT_AFTER:-0}" -gt 0 ]; then
  echo "✅ GraphDB repository is ready and has data!"
else
  echo "⚠️  Warning: Repository exists but triple count is 0"
fi

echo "============================================"
echo "🎉 GraphDB is ready for queries!"
echo "🌐 Internal URL : ${GRAPHDB_URL}"
echo "📦 Repository   : ${REPO_NAME}"
echo "🔗 SPARQL URL   : ${REPO_URL}"
echo "============================================"
