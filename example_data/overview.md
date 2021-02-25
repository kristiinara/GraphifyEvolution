# Using example data

1) Download neo4j community version (enterprise works as well)
2) Download [app_data.dump](app_data.dump).
3) Run bin/neo4j-admin load --from=app_data.dump --database=<db_name>
4) Make sure that database name is set as the default database in neo4j config file
5) Run bin/neo4j console 
6) Open browser http://localhost:7474
7) Run queries and explore data
