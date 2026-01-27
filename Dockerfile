# GraphDB with Auto-Initialization for Railway
FROM ontotext/graphdb:10.7.2

USER root

# Copy data files
COPY data/ontology/facilities.ttl /opt/graphdb/data/ontology/
COPY data/graph_data/areas.ttl /opt/graphdb/data/graph_data/
COPY data/graph_data/facilities_data.ttl /opt/graphdb/data/graph_data/

# Copy scripts
COPY init-graphdb.sh /opt/graphdb/init-graphdb.sh
COPY entrypoint.sh /opt/graphdb/entrypoint.sh
RUN chmod +x /opt/graphdb/init-graphdb.sh /opt/graphdb/entrypoint.sh

# Ensure GraphDB home exists + is writable by graphdb user
RUN mkdir -p /opt/graphdb/home && chown -R graphdb:graphdb /opt/graphdb/home

# Switch back to the default graphdb user
USER graphdb

EXPOSE 7200

ENTRYPOINT ["/opt/graphdb/entrypoint.sh"]
