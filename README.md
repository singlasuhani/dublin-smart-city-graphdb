# Dublin City Facilities - GraphDB Backend

This repository contains the GraphDB knowledge graph backend for the Dublin City Facilities application.

## 🚀 Quick Deploy to Render

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com)

1. **Create New Web Service** on [Render](https://render.com/dashboard)
2. **Connect this repository**
3. **Configure**:
   - **Name**: `dublin-graphdb`
   - **Runtime**: Docker
   - **Dockerfile**: `Dockerfile`
   - **Plan**: Starter ($7/month minimum - required for persistent storage)

4. **Add Persistent Disk**:
   - Name: `graphdb-data`
   - Mount Path: `/opt/graphdb/home`
   - Size: 10 GB

5. **Deploy** - GraphDB will automatically:
   - ✅ Start GraphDB server
   - ✅ Create `dublin_facilities` repository
   - ✅ Load all RDF data files
   - ✅ Be ready for queries!

## 📊 What's Included

This repository contains:

- **Ontology**: Dublin City Facilities vocabulary and schema (`data/ontology/facilities.ttl`)
- **Committee Areas**: 5 Dublin city committee areas (`data/graph_data/areas.ttl`)
- **Facilities Data**: Complete facilities dataset (`data/graph_data/facilities_data.ttl`)

## 🔧 Run Locally with Docker

```bash
# Build the image
docker build -t dublin-graphdb .

# Run the container
docker run -d \
  --name graphdb \
  -p 7200:7200 \
  -v graphdb_data:/opt/graphdb/home \
  dublin-graphdb

# Check logs
docker logs -f graphdb
```

Access GraphDB at: **http://localhost:7200**

## 🌐 Access Your Deployed GraphDB

After deployment, your GraphDB will be available at:
```
https://your-app-name.onrender.com
```

### SPARQL Endpoint
```
https://your-app-name.onrender.com/repositories/dublin_facilities
```

### Test Query

```sparql
PREFIX ex: <http://example.org/dcc/facilities#>
PREFIX schema: <http://schema.org/>

SELECT ?name ?type WHERE {
  ?facility a ex:Facility ;
            schema:name ?name ;
            ex:hasFacilityType ?type .
} LIMIT 10
```

## 🔗 Connect to Your API

Update your API's environment variable:

```bash
GRAPHDB_URL=https://your-graphdb.onrender.com/repositories/dublin_facilities
```

## 📦 Data Structure

```
data/
├── ontology/
│   └── facilities.ttl          # Schema definition
└── graph_data/
    ├── areas.ttl               # Committee areas
    └── facilities_data.ttl     # Facilities dataset
```

## 🐛 Troubleshooting

### Check if GraphDB is Running
```bash
curl https://your-app.onrender.com/rest/repositories
```

### Check Triple Count
```bash
curl "https://your-app.onrender.com/repositories/dublin_facilities?query=SELECT%20(COUNT(*)%20as%20?count)%20WHERE%20{%20?s%20?p%20?o%20}" \
  -H "Accept: application/sparql-results+json"
```

### View Initialization Logs
Check Render dashboard → Your service → **Logs** tab

## 💰 Costs

- **Free Tier**: ❌ Not suitable (databases need persistent storage)
- **Starter Plan**: ✅ $7/month (always-on, 512MB RAM, persistent disk included)
- **Standard Plan**: $25/month (better performance)

## 📚 Resources

- [GraphDB Documentation](https://graphdb.ontotext.com/documentation/)
- [SPARQL 1.1 Query Language](https://www.w3.org/TR/sparql11-query/)
- [Render Docker Deployment](https://render.com/docs/docker)

## 🔒 Security Notes

> [!WARNING]
> This setup has **no authentication** enabled. For production use, you should:
> - Enable GraphDB security
> - Add username/password authentication
> - Use environment variables for credentials
> - Restrict network access

## 📄 License

This is a knowledge graph dataset for Dublin City Council facilities.
