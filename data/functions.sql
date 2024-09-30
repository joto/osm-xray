-- ---------------------------------------------------------------------------
--
-- SQL functions for OSM X-RAY tile server
--
-- ---------------------------------------------------------------------------

DROP TABLE IF EXISTS tile_cache;

-- This table is used to cache rendered tiles. Because it is unlogged it will
-- not survive a crash, but it is only a cache so that's okay.
CREATE UNLOGGED TABLE tile_cache (
    z int NOT NULL,
    x int NOT NULL,
    y int NOT NULL,
    layer text NOT NULL,
    data bytea NOT NULL,
    PRIMARY KEY (z, x, y, layer)
);

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_nodes_overview_low(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    result bytea;
    px CONSTANT int := x;
    py CONSTANT int := y;
    compression CONSTANT int := 6;
BEGIN
    CASE z
        WHEN 10 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z10 w WHERE w.x = px AND w.y = py;
        WHEN  9 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z9  w WHERE w.x = px AND w.y = py;
        WHEN  8 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z8  w WHERE w.x = px AND w.y = py;
        WHEN  7 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z7  w WHERE w.x = px AND w.y = py;
        WHEN  6 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z6  w WHERE w.x = px AND w.y = py;
        WHEN  5 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z5  w WHERE w.x = px AND w.y = py;
        WHEN  4 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z4  w WHERE w.x = px AND w.y = py;
        WHEN  3 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z3  w WHERE w.x = px AND w.y = py;
        WHEN  2 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z2  w WHERE w.x = px AND w.y = py;
        WHEN  1 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z1  w WHERE w.x = px AND w.y = py;
        WHEN  0 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_nodes_z0  w WHERE w.x = px AND w.y = py;
    END CASE;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_nodes_overview_mid(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 1024;
    buffer_size CONSTANT int := CASE z WHEN 13 THEN 20 WHEN 12 THEN 22 ELSE 25 END CASE;
    result bytea;
BEGIN
    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    dim AS (
        SELECT ST_XMin(tile) AS xmin, ST_YMax(tile) AS ymin, ST_XMax(tile) - ST_XMin(tile) AS width, ST_YMax(tile) - ST_YMin(tile) AS height FROM bounds
    ),
    empty_raster AS (
        SELECT ST_AddBand(ST_MakeEmptyRaster(extent, extent, xmin, ymin, width / extent, -height / extent, 0.0, 0.0, 3857), '8BUI', 255.0, 255.0) AS erast FROM dim
    ),
    geoms AS (
        SELECT ST_Buffer(geom, buffer_size) AS geom FROM osm_nodes, bounds WHERE osm_nodes.geom && bounds.tile
    ),
    collected AS (
        SELECT ST_Collect(geom) AS geom FROM geoms
    )
    SELECT ST_AsPNG(ST_SetValue(erast, geom, 0.0), 1, 6) INTO result FROM collected, empty_raster;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_nodes(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z <= 10 THEN
        SELECT osmdata_nodes_overview_low(z, x, y) INTO result;
        RETURN result;
    END IF;

    IF z < 14 THEN
        SELECT osmdata_nodes_overview_mid(z, x, y) INTO result;
        RETURN result;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mvtgeom AS (
        SELECT node_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags
            FROM osm_nodes, bounds
            WHERE ST_Intersects(geom, tile)
    )
    SELECT ST_AsMVT(mvtgeom, 'nodes', extent, 'geom', 'node_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_ways_overview_low(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    result bytea;
    px CONSTANT int := x;
    py CONSTANT int := y;
    compression CONSTANT int := 6;
BEGIN
    CASE z
        WHEN 10 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z10 w WHERE w.x = px AND w.y = py;
        WHEN  9 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z9  w WHERE w.x = px AND w.y = py;
        WHEN  8 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z8  w WHERE w.x = px AND w.y = py;
        WHEN  7 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z7  w WHERE w.x = px AND w.y = py;
        WHEN  6 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z6  w WHERE w.x = px AND w.y = py;
        WHEN  5 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z5  w WHERE w.x = px AND w.y = py;
        WHEN  4 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z4  w WHERE w.x = px AND w.y = py;
        WHEN  3 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z3  w WHERE w.x = px AND w.y = py;
        WHEN  2 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z2  w WHERE w.x = px AND w.y = py;
        WHEN  1 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z1  w WHERE w.x = px AND w.y = py;
        WHEN  0 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_ways_z0  w WHERE w.x = px AND w.y = py;
    END CASE;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_ways_overview_mid(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 1024;
    result bytea;
BEGIN
    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    dim AS (
        SELECT ST_XMin(tile) AS xmin, ST_YMax(tile) AS ymin, ST_XMax(tile) - ST_XMin(tile) AS width, ST_YMax(tile) - ST_YMin(tile) AS height FROM bounds
    ),
    empty_raster AS (
        SELECT ST_AddBand(ST_MakeEmptyRaster(extent, extent, xmin, ymin, width / extent, -height / extent, 0.0, 0.0, 3857), '8BUI', 255.0, 255.0) AS erast FROM dim
    ),
    geoms AS (
        SELECT ST_Intersection(CASE ST_GeometryType(geom)
            WHEN 'ST_LineString' THEN geom
            ELSE ST_ExteriorRing(geom)
        END, tile)
        AS geom FROM osm_ways, bounds WHERE geom && tile
    ),
    collected AS (
        SELECT ST_Collect(geom) AS geom FROM geoms
    )
    SELECT ST_AsPNG(ST_SetValue(erast, geom, 0.0), 1, 6) INTO result FROM collected, empty_raster;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_ways(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 4096;
    result bytea;
BEGIN
    IF z <= 10 THEN
        SELECT osmdata_ways_overview_low(z, x, y) INTO result;
        RETURN result;
    END IF;

    IF z < 14 THEN
        SELECT osmdata_ways_overview_mid(z, x, y) INTO result;
        RETURN result;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mvtgeom AS (
        SELECT way_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
            ST_XMin(ST_Transform(geom, 4326)) AS "@xmin",
            ST_YMin(ST_Transform(geom, 4326)) AS "@ymin",
            ST_XMax(ST_Transform(geom, 4326)) AS "@xmax",
            ST_YMax(ST_Transform(geom, 4326)) AS "@ymax"
            FROM osm_ways, bounds
            WHERE ST_Intersects(geom, tile)
    )
    SELECT ST_AsMVT(mvtgeom, 'ways', extent, 'geom', 'way_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_relations_overview(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 512;
    grid_size CONSTANT real := ((20037508.342789244 * 2) / (2 ^ z) / extent);
    result bytea;
BEGIN
    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    tile_extract AS (
        SELECT osm_rel_members.geom
            FROM osm_rel_members, bounds
            WHERE ST_Intersects(geom, tile)
    ),
    nodes AS (
        SELECT ST_Collect(ST_SnapToGrid(geom, grid_size)) AS geom
            FROM tile_extract
            WHERE ST_GeometryType(geom) = 'ST_Point'
    ),
    seg AS (
        SELECT ST_DumpSegments(ST_SnapToGrid(geom, grid_size)) AS segments
            FROM tile_extract
            WHERE ST_GeometryType(geom) = 'ST_LineString'
    ),
    seg2 AS (
        SELECT DISTINCT (seg.segments).geom AS geom FROM seg
    ),
    lm AS (
        SELECT ST_LineMerge(ST_Collect(geom)) AS geom FROM seg2
            WHERE ST_Length(geom) > grid_size
        UNION
        SELECT geom FROM osm_nodes
    ),
    mvtgeom AS (
        SELECT 0 AS rel_id, ST_AsMVTGeom(geom, tile, extent) AS geom
            FROM lm, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'public.osmdata_relations', extent, 'geom', 'rel_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_relations_overview_low(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    result bytea;
    px CONSTANT int := x;
    py CONSTANT int := y;
    compression CONSTANT int := 6;
BEGIN
    CASE z
        WHEN 10 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z10 w WHERE w.x = px AND w.y = py;
        WHEN  9 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z9  w WHERE w.x = px AND w.y = py;
        WHEN  8 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z8  w WHERE w.x = px AND w.y = py;
        WHEN  7 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z7  w WHERE w.x = px AND w.y = py;
        WHEN  6 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z6  w WHERE w.x = px AND w.y = py;
        WHEN  5 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z5  w WHERE w.x = px AND w.y = py;
        WHEN  4 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z4  w WHERE w.x = px AND w.y = py;
        WHEN  3 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z3  w WHERE w.x = px AND w.y = py;
        WHEN  2 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z2  w WHERE w.x = px AND w.y = py;
        WHEN  1 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z1  w WHERE w.x = px AND w.y = py;
        WHEN  0 THEN SELECT ST_AsPNG(rast, 1, compression) INTO result FROM osm_relations_z0  w WHERE w.x = px AND w.y = py;
    END CASE;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_relations_overview_mid(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 1024;
    buffer_size CONSTANT int := CASE z WHEN 13 THEN 20
                                       WHEN 12 THEN 22
                                       ELSE 25
                                END CASE;
    result bytea;
BEGIN
    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    dim AS (
        SELECT ST_XMin(tile) AS xmin, ST_YMax(tile) AS ymin, ST_XMax(tile) - ST_XMin(tile) AS width, ST_YMax(tile) - ST_YMin(tile) AS height FROM bounds
    ),
    empty_raster AS (
        SELECT ST_AddBand(ST_MakeEmptyRaster(extent, extent, xmin, ymin, width / extent, -height / extent, 0.0, 0.0, 3857), '8BUI', 255.0, 255.0) AS erast FROM dim
    ),
    rels_polygons AS (
        SELECT (ST_Dump(geom)).geom AS geom FROM osm_rels_mp, bounds WHERE geom && tile
    ),
    rels_rings AS (
        SELECT (ST_DumpRings(geom)).geom AS geom FROM rels_polygons
    ),
    geoms AS (
        SELECT CASE ST_GeometryType(geom)
            WHEN 'ST_LineString' THEN geom
            ELSE ST_Buffer(geom, buffer_size, 'quad_segs=2')
        END AS geom
        FROM osm_rel_members, bounds WHERE geom && tile
        UNION
        SELECT ST_ExteriorRing(geom) FROM rels_rings
    ),
    intersected AS (
        SELECT ST_Intersection(geom, tile) AS geom FROM geoms, bounds
    ),
    collected AS (
        SELECT ST_Collect(geom) AS geom FROM intersected
    )
    SELECT ST_AsPNG(ST_SetValue(erast, geom, 0.0), 1, 6) INTO result FROM collected, empty_raster;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_relations(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z <= 10 THEN
        SELECT osmdata_relations_overview_low(z, x, y) INTO result;
        RETURN result;
    END IF;

    IF z < 14 THEN
        SELECT osmdata_relations_overview_mid(z, x, y) INTO result;
        RETURN result;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mps AS (
        SELECT rel_id, geom, tags, x_min, y_min, x_max, y_max
            FROM osm_rels_mp, bounds
            WHERE geom && tile AND ST_Intersects(ST_Boundary(geom), tile)
    ),
    members AS (
        SELECT rel_id, ST_Intersection(geom, ST_Expand(tile, (ST_XMax(tile) - ST_XMin(tile)) / 16)) AS geom, tags, x_min, y_min, x_max, y_max
            FROM osm_rel_members, bounds
            WHERE geom && tile
    ),
    merged AS (
        SELECT * FROM mps
        UNION
        SELECT * FROM members
    ),
    mvtgeom AS (
        SELECT rel_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
            x_min AS "@xmin", y_min AS "@ymin", x_max AS "@xmax", y_max AS "@ymax"
            FROM merged, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'relations', extent, 'geom', 'rel_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_nodes_with_key(z integer, x integer, y integer, key text DEFAULT '')
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z < 14 THEN
        extent := 1024;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mvtgeom AS (
        SELECT node_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags
            FROM osm_nodes, bounds
            WHERE ST_Intersects(geom, tile)
            AND osm_nodes.tags ? key
    )
    SELECT ST_AsMVT(mvtgeom, 'nodes', extent, 'geom', 'node_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_nodes_with_tag(z integer, x integer, y integer, key text DEFAULT NULL, value text DEFAULT '')
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z < 14 THEN
        extent := 1024;
    END IF;

    IF key IS NULL THEN
        WITH
        bounds AS (
            SELECT ST_TileEnvelope(z, x, y) AS tile
        ),
        mvtgeom AS (
            SELECT node_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags
                FROM osm_nodes, bounds
                WHERE ST_Intersects(geom, tile)
                AND jsonb_path_exists(tags, ('$.keyvalue()[*] ? (@.value == "' || value || '")')::jsonpath)
        )
        SELECT ST_AsMVT(mvtgeom, 'nodes', extent, 'geom', 'node_id')
            INTO result
            FROM mvtgeom;

        RETURN result;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mvtgeom AS (
        SELECT node_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags
            FROM osm_nodes, bounds
            WHERE ST_Intersects(geom, tile)
            AND osm_nodes.tags->>key = value
    )
    SELECT ST_AsMVT(mvtgeom, 'nodes', extent, 'geom', 'node_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_ways_with_key(z integer, x integer, y integer, key text DEFAULT '')
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z < 14 THEN
        extent := 2048;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mvtgeom AS (
        SELECT way_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
            ST_XMin(ST_Transform(geom, 4326)) AS "@xmin",
            ST_YMin(ST_Transform(geom, 4326)) AS "@ymin",
            ST_XMax(ST_Transform(geom, 4326)) AS "@xmax",
            ST_YMax(ST_Transform(geom, 4326)) AS "@ymax"
            FROM osm_ways, bounds
            WHERE ST_Intersects(geom, tile)
            AND osm_ways.tags ? key
    )
    SELECT ST_AsMVT(mvtgeom, 'ways', extent, 'geom', 'way_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_ways_with_tag(z integer, x integer, y integer, key text DEFAULT NULL, value text DEFAULT '')
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z < 14 THEN
        extent := 2048;
    END IF;

    IF key IS NULL THEN
        WITH
        bounds AS (
            SELECT ST_TileEnvelope(z, x, y) AS tile
        ),
        mvtgeom AS (
            SELECT way_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
                ST_XMin(ST_Transform(geom, 4326)) AS "@xmin",
                ST_YMin(ST_Transform(geom, 4326)) AS "@ymin",
                ST_XMax(ST_Transform(geom, 4326)) AS "@xmax",
                ST_YMax(ST_Transform(geom, 4326)) AS "@ymax"
                FROM osm_ways, bounds
                WHERE ST_Intersects(geom, tile)
                AND jsonb_path_exists(tags, ('$.keyvalue()[*] ? (@.value == "' || value || '")')::jsonpath)
        )
        SELECT ST_AsMVT(mvtgeom, 'ways', extent, 'geom', 'way_id')
            INTO result
            FROM mvtgeom;

        RETURN result;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mvtgeom AS (
        SELECT way_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
            ST_XMin(ST_Transform(geom, 4326)) AS "@xmin",
            ST_YMin(ST_Transform(geom, 4326)) AS "@ymin",
            ST_XMax(ST_Transform(geom, 4326)) AS "@xmax",
            ST_YMax(ST_Transform(geom, 4326)) AS "@ymax"
            FROM osm_ways, bounds
            WHERE ST_Intersects(geom, tile)
            AND osm_ways.tags->>key = value
    )
    SELECT ST_AsMVT(mvtgeom, 'ways', extent, 'geom', 'way_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_relations_with_key(z integer, x integer, y integer, key text DEFAULT '')
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z < 14 THEN
        extent := 1024;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mps AS (
        SELECT rel_id, geom, tags, x_min, y_min, x_max, y_max
            FROM osm_rels_mp, bounds
            WHERE geom && tile AND ST_Intersects(ST_Boundary(geom), tile)
            AND tags ? key
    ),
    members AS (
        SELECT rel_id, ST_Intersection(geom, ST_Expand(tile, (ST_XMax(tile) - ST_XMin(tile)) / 16)) AS geom, tags, x_min, y_min, x_max, y_max
            FROM osm_rel_members, bounds
            WHERE geom && tile
            AND tags ? key
    ),
    merged AS (
        SELECT * FROM mps
        UNION
        SELECT * FROM members
    ),
    mvtgeom AS (
        SELECT rel_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
            x_min AS "@xmin", y_min AS "@ymin", x_max AS "@xmax", y_max AS "@ymax"
            FROM merged, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'relations', extent, 'geom', 'rel_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.osmdata_relations_with_tag(z integer, x integer, y integer, key text DEFAULT NULL, value text DEFAULT '')
RETURNS bytea
AS $$
DECLARE
    extent int := 4096;
    result bytea;
BEGIN
    IF z < 14 THEN
        extent := 1024;
    END IF;

    IF key IS NULL THEN
        WITH
        bounds AS (
            SELECT ST_TileEnvelope(z, x, y) AS tile
        ),
        mps AS (
            SELECT rel_id, geom, tags, x_min, y_min, x_max, y_max
                FROM osm_rels_mp, bounds
                WHERE geom && tile AND ST_Intersects(ST_Boundary(geom), tile)
                AND jsonb_path_exists(tags, ('$.keyvalue()[*] ? (@.value == "' || value || '")')::jsonpath)
        ),
        members AS (
            SELECT rel_id, ST_Intersection(geom, ST_Expand(tile, (ST_XMax(tile) - ST_XMin(tile)) / 16)) AS geom, tags, x_min, y_min, x_max, y_max
                FROM osm_rel_members, bounds
                WHERE geom && tile
                AND tags->>key = value
        ),
        merged AS (
            SELECT * FROM mps
            UNION
            SELECT * FROM members
        ),
        mvtgeom AS (
            SELECT rel_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
                x_min AS "@xmin", y_min AS "@ymin", x_max AS "@xmax", y_max AS "@ymax"
                FROM merged, bounds
        )
        SELECT ST_AsMVT(mvtgeom, 'relations', extent, 'geom', 'rel_id')
            INTO result
            FROM mvtgeom;

        RETURN result;
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    mps AS (
        SELECT rel_id, geom, tags, x_min, y_min, x_max, y_max
            FROM osm_rels_mp, bounds
            WHERE geom && tile AND ST_Intersects(ST_Boundary(geom), tile)
            AND tags->>key = value
    ),
    members AS (
        SELECT rel_id, ST_Intersection(geom, ST_Expand(tile, (ST_XMax(tile) - ST_XMin(tile)) / 16)) AS geom, tags, x_min, y_min, x_max, y_max
            FROM osm_rel_members, bounds
            WHERE geom && tile
            AND tags->>key = value
    ),
    merged AS (
        SELECT * FROM mps
        UNION
        SELECT * FROM members
    ),
    mvtgeom AS (
        SELECT rel_id, ST_AsMVTGeom(geom, tile, extent) AS geom, tags,
            x_min AS "@xmin", y_min AS "@ymin", x_max AS "@xmax", y_max AS "@ymax"
            FROM merged, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'relations', extent, 'geom', 'rel_id')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql'
STABLE
PARALLEL SAFE;

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.nodes(z integer, x integer, y integer, key text DEFAULT NULL, value text DEFAULT NULL)
RETURNS bytea
AS $$
DECLARE
    result bytea;
BEGIN
    IF value IS NOT NULL THEN
        RETURN public.osmdata_nodes_with_tag(z, x, y, key, value);
    END IF;

    IF key IS NOT NULL THEN
        RETURN public.osmdata_nodes_with_key(z, x, y, key);
    END IF;

    IF z < 14 THEN
        SELECT data FROM tile_cache c WHERE c.z = nodes.z AND c.x = nodes.x AND c.y = nodes.y AND c.layer = 'nodes'
            INTO result;

        IF NOT FOUND THEN
            result := public.osmdata_nodes(z, x, y);
            INSERT INTO tile_cache (z, x, y, layer, data)
                VALUES (z, x, y, 'nodes', coalesce(result, ''::bytea))
                ON CONFLICT DO NOTHING;
        END IF;
    ELSE
        result := public.osmdata_nodes(z, x, y);
    END IF;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql';

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.ways(z integer, x integer, y integer, key text DEFAULT NULL, value text DEFAULT NULL)
RETURNS bytea
AS $$
DECLARE
    result bytea;
BEGIN
    IF value IS NOT NULL THEN
        RETURN public.osmdata_ways_with_tag(z, x, y, key, value);
    END IF;

    IF key IS NOT NULL THEN
        RETURN public.osmdata_ways_with_key(z, x, y, key);
    END IF;

    IF z < 14 THEN
        SELECT data FROM tile_cache c WHERE c.z = ways.z AND c.x = ways.x AND c.y = ways.y AND c.layer = 'ways'
            INTO result;

        IF NOT FOUND THEN
            result := public.osmdata_ways(z, x, y);
            INSERT INTO tile_cache (z, x, y, layer, data)
                VALUES (z, x, y, 'ways', coalesce(result, ''::bytea))
                ON CONFLICT DO NOTHING;
        END IF;
    ELSE
        result := public.osmdata_ways(z, x, y);
    END IF;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql';

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.relations(z integer, x integer, y integer, key text DEFAULT NULL, value text DEFAULT NULL)
RETURNS bytea
AS $$
DECLARE
    result bytea;
BEGIN
    IF value IS NOT NULL THEN
        RETURN public.osmdata_relations_with_tag(z, x, y, key, value);
    END IF;

    IF key IS NOT NULL THEN
        RETURN public.osmdata_relations_with_key(z, x, y, key);
    END IF;

    IF z < 14 THEN
        SELECT data FROM tile_cache c WHERE c.z = relations.z AND c.x = relations.x AND c.y = relations.y AND c.layer = 'relations'
            INTO result;

        IF NOT FOUND THEN
            result := public.osmdata_relations(z, x, y);
            INSERT INTO tile_cache (z, x, y, layer, data)
                VALUES (z, x, y, 'relations', coalesce(result, ''::bytea))
                ON CONFLICT DO NOTHING;
        END IF;
    ELSE
        result := public.osmdata_relations(z, x, y);
    END IF;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql';

-- ---------------------------------------------------------------------------

CREATE OR REPLACE
FUNCTION public.boundaries_s(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 1024;
    result bytea;
BEGIN
    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    boundaries AS (
        SELECT admin_level, geom
            FROM osm_boundaries_s, bounds
            WHERE geom && tile AND maritime = false AND disputed = false
                AND admin_level = 2
    ),
    mvtgeom AS (
        SELECT admin_level, ST_AsMVTGeom(geom, tile, extent) AS geom
            FROM boundaries, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'boundaries', extent, 'geom')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE
FUNCTION public.boundaries_m(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 1024;
    result bytea;
BEGIN
    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    boundaries AS (
        SELECT admin_level, geom
            FROM osm_boundaries_m, bounds
            WHERE geom && tile AND maritime = false AND disputed = false
    ),
    mvtgeom AS (
        SELECT admin_level, ST_AsMVTGeom(geom, tile, extent) AS geom
            FROM boundaries, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'boundaries', extent, 'geom')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE
FUNCTION public.boundaries_l(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 1024;
    result bytea;
BEGIN
    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    boundaries AS (
        SELECT admin_level, geom
            FROM osm_boundaries_l, bounds
            WHERE geom && tile AND maritime = false AND disputed = false
    ),
    mvtgeom AS (
        SELECT admin_level, ST_AsMVTGeom(geom, tile, extent) AS geom
            FROM boundaries, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'boundaries', extent, 'geom')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql';

CREATE OR REPLACE
FUNCTION public.boundaries(z integer, x integer, y integer)
RETURNS bytea
AS $$
DECLARE
    extent CONSTANT int := 4096;
    result bytea;
BEGIN
    IF z < 5 THEN
        RETURN public.boundaries_s(z, x, y);
    END IF;

    IF z < 7 THEN
        RETURN public.boundaries_m(z, x, y);
    END IF;

    IF z < 9 THEN
        RETURN public.boundaries_l(z, x, y);
    END IF;

    WITH
    bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS tile
    ),
    boundaries AS (
        SELECT admin_level, geom
            FROM osm_boundaries, bounds
            WHERE geom && tile AND maritime = false AND disputed = false
    ),
    mvtgeom AS (
        SELECT admin_level, ST_AsMVTGeom(geom, tile, extent) AS geom
            FROM boundaries, bounds
    )
    SELECT ST_AsMVT(mvtgeom, 'boundaries', extent, 'geom')
        INTO result
        FROM mvtgeom;

    RETURN result;
END;
$$
LANGUAGE 'plpgsql';

-- ---------------------------------------------------------------------------
