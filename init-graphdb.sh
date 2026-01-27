#!/bin/bash
# GraphDB Auto-Initialization Script for Railway
# Creates repository and loads RDF data automatically on container startup

set -euo pipefail

GRAPHDB_URL="${GRAPHDB_URL:-http://localhost:7200}"
REPO_NAME="${REPO_NAME:-city_facilities}"
REPO_URL="$GRAPHDB_URL/repositories/$REPO_NAME"

echo "============================================"
echo "🚂 Railway GraphDB Initialization"
echo "============================================"
echo "GRAPHDB_URL: $GRAPHDB_URL"
echo "REPO_NAME  : $REPO_NAME"
echo "============================================"

# Wait for GraphDB to be fully ready
echo "⏳ Waiting for GraphDB to start..."
MAX_RETRIES=60
RETRY_COUNT=0

until curl -sS "$GRAPHDB_URL/rest/repositories" >/dev/null; do
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ "$RETRY_COUNT" -gt "$MAX_RETRIES" ]; then
    echo "❌ ERROR: GraphDB failed to start after $MAX_RETRIES attempts"
    echo "Showing GraphDB logs:"
    if [ -f /opt/graphdb/home/logs/main.log ]; then
      tail -n 200 /opt/graphdb/home/logs/main.log || true
    fi
    exit 1
  fi
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
  sleep 5
done

echo "✅ GraphDB is ready!"

# Check if repository already exists
echo "🔍 Checking if repository exists..."
if curl -sS "$GRAPHDB_URL/rest/repositories" | grep -q "\"$REPO_NAME\""; then
  echo "✅ Repository '$REPO_NAME' already exists"
else
  echo "📦 Creating repository '$REPO_NAME' (TTL config)..."

  cat > /tmp/repo-config.ttl <<EOF
@prefix rep: <http://www.openrdf.org/config/repository#> .
@prefix sr: <http://www.openrdf.org/config/repository/sail#> .
@prefix sail: <http://www.openrdf.org/config/sail#> .

[] a rep:Repository ;
   rep:repositoryID "$REPO_NAME" ;
   rep:repositoryImpl [
      rep:repositoryType "graphdb:SailRepository" ;
      sr:sailImpl [
         sail:sailType "graphdb:Sail"
      ]
   ] .
EOF

  # Create repository (fail loudly if GraphDB returns 4xx/5xx)
  curl -f -sS -X POST "$GRAPHDB_URL/rest/repositories" \
    -H "Content-Type: text/turtle" \
    --data-binary @/tmp/repo-config.ttl

  echo "✅ Repository created successfully"
fi

# Wait for repository to be ready
sleep 2

echo "============================================"
echo "📊 Checking triple count..."
echo "============================================"

COUNT_BEFORE=$(
  curl -sS -G "$REPO_URL" \
    --data-urlencode 'query=SELECT (COUNT(*) as ?count) WHERE { ?s ?p ?o }' \
    -H "Accept: application/sparql-results+json" 2>/dev/null \
  | grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0"
)

echo "📈 Current triples: $COUNT_BEFORE"

# Only load if empty (prevents duplicates on redeploy)
if [ "${COUNT_BEFORE:-0}" -eq 0 ]; then
  echo "============================================"
  echo "📚 Loading RDF Data Files..."
  echo "============================================"

  echo "1/3 Loading facilities ontology..."
  curl -f -sS -X POST "$REPO_URL/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @/opt/graphdb/data/ontology/facilities.ttl
  echo "  ✅ Ontology loaded"

  echo "2/3 Loading committee areas..."
  curl -f -sS -X POST "$REPO_URL/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @/opt/graphdb/data/graph_data/areas.ttl
  echo "  ✅ Areas loaded"

  echo "3/3 Loading facilities data..."
  curl -f -sS -X POST "$REPO_URL/statements" \
    -H "Content-Type: text/turtle" \
    --data-binary @/opt/graphdb/data/graph_data/facilities_data.ttl
  echo "  ✅ Facilities loaded"
else
  echo "✅ Repo already has data — skipping load to avoid duplicates."
fi

echo ""
echo "============================================"
echo "📊 Verification"
echo "============================================"

COUNT_AFTER=$(
  curl -sS -G "$REPO_URL" \
    --data-urlencode 'query=SELECT (COUNT(*) as ?count) WHERE { ?s ?p ?o }' \
    -H "Accept: application/sparql-results+json" 2>/dev/null \
  | grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0"
)

echo "📈 Total triples loaded: $COUNT_AFTER"

if [ "${COUNT_AFTER:-0}" -gt 0 ]; then
  echo "✅ Data successfully loaded!"
else
  echo "⚠️  Warning: No triples found in repository"
fi

echo "============================================"
echo "🎉 GraphDB is ready for queries!"
echo "🌐 Access at: $GRAPHDB_URL"
echo "📦 Repository: $REPO_NAME"
echo "============================================"
