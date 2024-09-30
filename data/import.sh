#!/usr/bin/bash
# ----------------------------------------------------------------------------

set -euo pipefail

# ----------------------------------------------------------------------------

DB=osm
OSMFILE=/data/planet.osm.pbf
FLATNODES=/data/flat.nodes
UPDATES=YES

# ----------------------------------------------------------------------------

slim=""
if [ "$UPDATES" = "YES" ]; then
    slim="--slim"
fi

osm2pgsql -d "$DB" -O flex -S import/xray.lua "$slim" -F "$FLATNODES" "$OSMFILE"

osm2pgsql-gen -d "$DB" -S import/xray.lua -j16

psql osm <import/functions.sql

if [ "$UPDATES" = "YES" ]; then
    osm2pgsql-replication init -d "$DB" --server https://planet.osm.org/replication/minute/
fi

# ----------------------------------------------------------------------------
