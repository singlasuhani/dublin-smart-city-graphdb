# GraphDB for Railway - Simplified (Manual Repository Creation)
FROM ontotext/graphdb:10.7.2

# Set working directory
USER root
WORKDIR /opt/graphdb/home

# Copy data files for manual import
COPY data/ontology/facilities.ttl /opt/graphdb/data/ontology/
COPY data/graph_data/areas.ttl /opt/graphdb/data/graph_data/
COPY data/graph_data/facilities_data.ttl /opt/graphdb/data/graph_data/

# Expose GraphDB port
EXPOSE 7200

# Start GraphDB in server-only mode (no workbench UI overhead)