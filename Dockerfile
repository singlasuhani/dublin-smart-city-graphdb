# GraphDB with Auto-Initialization for Railway
FROM ontotext/graphdb:10.7.2

# Set working directory and switch to root for file operations
USER root
WORKDIR /opt/graphdb/home

# Copy data files
COPY data/ontology/facilities.ttl /opt/graphdb/data/ontology/
COPY data/graph_data/areas.ttl /opt/graphdb/data/graph_data/
COPY data/graph_data/facilities_data.ttl /opt/graphdb/data/graph_data/

# Copy initialization script
COPY init-graphdb.sh /opt/graphdb/init-graphdb.sh
COPY entrypoint.sh /opt/graphdb/entrypoint.sh
RUN chmod +x /opt/graphdb/init-graphdb.sh /opt/graphdb/entrypoint.sh

# Expose GraphDB port (Railway auto-detects this)
EXPOSE 7200

# Use entrypoint script to start GraphDB properly
ENTRYPOINT ["/opt/graphdb/entrypoint.sh"]