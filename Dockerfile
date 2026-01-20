# GraphDB with Auto-Initialization for Railway
FROM ontotext/graphdb:10.7.2

# Install curl for initialization script
USER root
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /opt/graphdb/home

# Copy data files
COPY data/ontology/facilities.ttl /opt/graphdb/data/ontology/
COPY data/graph_data/areas.ttl /opt/graphdb/data/graph_data/
COPY data/graph_data/facilities_data.ttl /opt/graphdb/data/graph_data/

# Copy initialization script
COPY init-graphdb.sh /opt/graphdb/init-graphdb.sh
RUN chmod +x /opt/graphdb/init-graphdb.sh

# Expose GraphDB port (Railway auto-detects this)
EXPOSE 7200

# Switch back to graphdb user
USER graphdb

# Start GraphDB and run initialization in background
CMD ["/bin/bash", "-c", "/opt/graphdb/dist/bin/graphdb -Dgraphdb.home=/opt/graphdb/home & sleep 30 && /opt/graphdb/init-graphdb.sh && tail -f /opt/graphdb/home/logs/main.log"]