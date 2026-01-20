#!/bin/bash
# GraphDB Auto-Initialization Script
# Creates repository and loads RDF data automatically on container startup

set -e

GRAPHDB_URL="http://localhost:7200"
REPO_NAME="dublin_facilities"
REPO_URL="$GRAPHDB_URL/repositories/$REPO_NAME"

echo "============================================"
echo "GraphDB Auto-Initialization Starting..."
echo "============================================"

# Wait for GraphDB to be fully ready
echo "Waiting for GraphDB to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

until curl -sf "$GRAPHDB_URL/rest/repositories" > /dev/null 2>&1; do
    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -gt $MAX_RETRIES ]; then
        echo "❌ ERROR: GraphDB failed to start after $MAX_RETRIES attempts"
        exit 1
    fi
    echo "  Attempt $RETRY_COUNT/$MAX_RETRIES - GraphDB not ready yet, waiting..."
    sleep 5
done

echo "✓ GraphDB is ready!"

# Check if repository already exists
echo "Checking if repository exists..."
REPO_EXISTS=$(curl -s "$GRAPHDB_URL/rest/repositories" | grep -c "\"$REPO_NAME\"" || true)

if [ "$REPO_EXISTS" -eq 0 ]; then
    echo "Creating repository '$REPO_NAME'..."
    
    # Create repository using GraphDB REST API
    curl -X POST "$GRAPHDB_URL/rest/repositories" \
        -H "Content-Type: application/json" \
        -d '{
            "id": "'"$REPO_NAME"'",
            "title": "Dublin City Facilities Knowledge Graph",
            "type": "graphdb",
            "params": {
                "ruleset": {
                    "label": "Ruleset",
                    "name": "ruleset",
                    "value": "rdfsplus-optimized"
                },
                "enableContextIndex": {
                    "label": "Enable context index",
                    "name": "enableContextIndex",
                    "value": "true"
                },
                "enablePredicateList": {
                    "label": "Use predicate lists",
                    "name": "enablePredicateList",
                    "value": "true"
                },
                "queryTimeout": {
                    "label": "Query time-out (seconds)",
                    "name": "queryTimeout",
                    "value": "30"
                }
            }
        }' > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "✓ Repository created successfully"
    else
        echo "❌ Failed to create repository"
        exit 1
    fi
    
    # Wait for repository to be ready
    sleep 5
    
    echo "============================================"
    echo "Loading RDF Data Files..."
    echo "============================================"
    
    # Load ontology
    echo "1/3 Loading facilities ontology..."
    curl -X POST "$REPO_URL/statements" \
        -H "Content-Type: text/turtle" \
        --data-binary @/opt/graphdb/data/ontology/facilities.ttl \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Ontology loaded"
    else
        echo "  ❌ Failed to load ontology"
    fi
    
    # Load areas
    echo "2/3 Loading committee areas..."
    curl -X POST "$REPO_URL/statements" \
        -H "Content-Type: text/turtle" \
        --data-binary @/opt/graphdb/data/graph_data/areas.ttl \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Areas loaded"
    else
        echo "  ❌ Failed to load areas"
    fi
    
    # Load facilities
    echo "3/3 Loading facilities data..."
    curl -X POST "$REPO_URL/statements" \
        -H "Content-Type: text/turtle" \
        --data-binary @/opt/graphdb/data/graph_data/facilities_data.ttl \
        > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo "  ✓ Facilities loaded"
    else
        echo "  ❌ Failed to load facilities"
    fi
    
    # Get triple count
    echo ""
    echo "============================================"
    echo "Verification"
    echo "============================================"
    
    COUNT=$(curl -s "$REPO_URL?query=SELECT%20(COUNT(*)%20as%20?count)%20WHERE%20{%20?s%20?p%20?o%20}" \
        -H "Accept: application/sparql-results+json" 2>/dev/null | \
        grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0")
    
    echo "Total triples loaded: $COUNT"
    
    if [ "$COUNT" -gt 0 ]; then
        echo "✓ Data successfully loaded!"
    else
        echo "⚠ Warning: No triples found in repository"
    fi
    
else
    echo "✓ Repository '$REPO_NAME' already exists (skipping creation)"
    
    # Still show triple count
    COUNT=$(curl -s "$REPO_URL?query=SELECT%20(COUNT(*)%20as%20?count)%20WHERE%20{%20?s%20?p%20?o%20}" \
        -H "Accept: application/sparql-results+json" 2>/dev/null | \
        grep -o '"value":"[0-9]*"' | head -1 | grep -o '[0-9]*' || echo "0")
    
    echo "Current triple count: $COUNT"
fi

echo "============================================"
echo "GraphDB is ready to accept queries!"
echo "Access at: $GRAPHDB_URL"
echo "Repository: $REPO_NAME"
echo "============================================"
