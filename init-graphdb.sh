#!/bin/bash
# GraphDB Auto-Initialization Script for Railway
# Creates repository and loads RDF data automatically on container startup

set -euo pipefail

GRAPHDB_URL="${GRAPHDB_URL:-http://localhost:7200}"
REPO_NAME="${REPO_NAME:-city_facilities}"
REPO_URL="$GRAPHDB_URL/repositories/$REPO_NAME"

ONTOLOGY_FILE="/opt/graphdb/data/ontology/facilities.ttl"
AREAS_FILE="/opt/graphdb/data/graph_data/areas.ttl"
FACILITIES_FILE="/opt/graphdb/data/graph_data/facilities_data.ttl"

echo "============================================"
echo "🚂 Railway GraphDB Initialization"
echo "============================================"
echo "GRAPHDB_URL: $GRAPHDB_URL"
echo "REPO_NAME  : $REPO_NAME"
echo "============================================"

# -----------------------------
# Wait for GraphDB to be ready
# -----------------------------
echo "⏳ Waiting for GraphDB to start..."
MAX_RETRIES=30
RETRY_COUNT=0

until curl -f -sS "$GRAPHDB_URL/rest/repositories" >/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ "$RETRY_COUNT" -gt "$MAX_RETRIES" ]; then
    echo "❌ ERROR: GraphDB failed to start after $MAX_RETRIES attempts"
    echo "Showing GraphDB logs (if available):"
    if [ -f /opt/graphdb/home/logs/main.log ]; then
      tail -n 200 /opt/graphdb/home/logs/main.log || true
    fi
    exit 1
  fi
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
  sleep 5
done

echo "✅ GraphDB is ready!"

# -----------------------------
# Check if repository exists
# -----------------------------
echo "🔍 Checking if repository exists..."
if curl -sS "$GRAPHDB_URL/rest/repositories" | grep -q "\"$REPO_NAME\""; then
  echo "✅ Repository '$REPO_NAME' already exists"
else
  echo "📦 Creating repository '$REPO_NAME' (TTL config)..."

  cat > /tmp/repo-config.ttl <<EOF
@prefix rep: <http://www.openrdf.org/config/repository#> .
@prefix sr: <http://www.openrdf.org/config/repository/sail#> .
@prefix sail: <http://www.openrdf.org/config/sail#> .
@prefix graphdb: <http://www.ontotext.com/config/graphdb#> .

[] a rep:Repository ;
   rep:repositoryID "$REPO_NAME" ;
   rep:repositoryImpl [
      rep:repositoryType "graphdb:SailRepository" ;
      sr:sailImpl [
         sail:sailType "graphdb:Sail" ;
         graphdb:ruleset "rdfsplus-optimized" ;
         graphdb:enable-context-index "true" ;
         graphdb:enablePredicateList "true" ;
         graphdb:enable-lucene-index "true"
      ]
   ] .
EOF

  # -f makes curl fail on 4xx/5xx so we can see errors in Railway logs
  curl -f -sS -X POST "$GRAPHDB_URL/rest/repositories" \
    -H "Content-Type: text/turtle" \
    --data-binary @/tmp/repo-config.ttl

  echo "✅ Repository created successfully"
fi

# Give GraphDB a moment to fully initialize the repo
sleep 2

# -----------------------------
# Load RDF data (only if repo is empty OR always? We'll do idempotent-ish load:
# If you redeploy and repo persists, you probably DON'T want duplicates.
# We'll only load if triple count is 0.
# -----------------------------
echo "============================================"
echo "📊 Checking current triple count..."
echo "============================================"

COUNT_BEFORE=$(
  curl -sS -G "$REPO_URL" \
    --data-urlencode 'query=SELECT (COUNT(*) as ?count) WHERE { ?s ?p ?o }' \
    -H "Accept: application/sparql-results+json" \
  | grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0"
)

echo "📈 Current triples in '$REPO_NAME': $COUNT_BEFORE"

if [ "${COUNT_BEFORE:-0}" -gt 0 ]; then
  echo "✅ Repository already has data. Skipping load to avoid duplicates."
else
  echo "============================================"
  echo "📚 Loading RDF Data Files..."
  echo "============================================"

  if [ ! -f "$ONTOLOGY_FILE" ]; then
    echo "❌ Missing ontology file: $ONTOLOGY_FILE"
    exit 1
  fi
  if [ ! -f "$AREAS_FILE" ]; then
    echo "❌ Missing areas file: $AREAS_FILE"
    exit 1
  fi
  if [ ! -f "$FACILITIES_FILE" ]; then
    echo "❌ Missing facilities data file: $FACILITIES_FILE"
    exit 1
  fi

  echo "1/3 Loading facilities ontology..."
  curl -f -sS -X POST "$REPO_URL/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @"$ONTOLOGY_FILE"
  echo "  ✅ Ontology loaded"

  echo "2/3 Loading committee areas..."
  curl -f -sS -X POST "$REPO_URL/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @"$AREAS_FILE"
  echo "  ✅ Areas loaded"

  echo "3/3 Loading facilities data..."
  curl -f -sS -X POST "$REPO_URL/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @"$FACILITIES_FILE"
  echo "  ✅ Facilities loaded"
fi

# -----------------------------
# Verification
# -----------------------------
echo ""
echo "============================================"
echo "📊 Verification"
echo "============================================"

COUNT_AFTER=$(
  curl -sS -G "$REPO_URL" \
    --data-urlencode 'query=SELECT (COUNT(*) as ?count) WHERE { ?s ?p ?o }' \
    -H "Accept: application/sparql-results+json" \
  | grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0"
)

echo "📈 Total triples in '$REPO_NAME': $COUNT_AFTER"

if [ "${COUNT_AFTER:-0}" -gt 0 ]; then
  echo "✅ GraphDB repository is ready and has data!"
else
  echo "⚠️  Warning: Repository exists but triple count is 0"
fi

echo "============================================"
echo "🎉 GraphDB is ready for queries!"
echo "🌐 Base URL   : $GRAPHDB_URL"
echo "📦 Repository : $REPO_NAME"
echo "🔗 SPARQL     : $REPO_URL"
echo "============================================"
