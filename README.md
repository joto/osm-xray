
# OSM X-RAY

OpenStreetMap Debug View showing all tagged nodes, ways, and relations.

## Prerequisites

You need

* [PostgreSQL](https://www.postgresql.org/) database with [PostGIS](https://postgis.net/) extension
* [osm2pgsql](https://osm2pgsql.org/) version 2.0.0 or above
* [osm2pgsql-themepark](https://osm2pgsql.org/themepark)
* [pg_tileserv](https://github.com/CrunchyData/pg_tileserv)
* [nginx](http://nginx.org/)

You'll need about 1 TB of disk space for an updatable full planet database.
During the first import considerably more is needed, make sure you have at
least another 500 GB available.

## Import

Install PostgreSQL/PostGIS database and create a database called `osm`.

Install extensions in the database:

```
CREATE EXTENSION postgis;
CREATE EXTENSION postgis_raster;
```

Change variables at start of `data/import.sh` and then run the script
to import the data.

If you want to update the data, also edit `data/update.sh`.

## Update

To update the data call

```
data/update.sh
```

You can do this in a loop to keep the data up-to-date.

Tiles for low zoom levels (0-10) are currently never updated.

## Tileserver

Install pg_tileserv and run it with something like this (use suitable URL
to access your database):

```
export DATABASE_URL=postgresql://USER:USER@localhost/osm
pg_tileserv
```

You should be able to access the tile server at http://localhost:7800/.

Install the NGINX config `server/nginx-config` and restart the nginx server.
This instructs NGINX to forward requests to pg_tileserve.

## Web

Put the contents of the `web` directory on a web server. Change the `urlPrefix`
at the beginning of `web/map.js` to point to the tile server.

## License

Copyright (C) 2024  Jochen Topf (jochen@topf.org)

This program is available under the GNU GENERAL PUBLIC LICENSE Version 3.
See the file LICENSE.txt for the complete text of the license.

## Author

Developed and maintained by Jochen Topf (jochen@topf.org).

