-- ---------------------------------------------------------------------------
--
-- Theme: xray
-- Topic: relations-lowzoom
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

theme.create_lowzoom_table('relations')

local function generate_relations_midzoom(zoom)
    theme.generate_raster_midzoom('rel_members', 'relations', zoom, [[
outer_rings AS (
    SELECT (ST_Dump(geom)).geom AS geom FROM ]] ..
    theme.prefix ..
    [[rels_mp, bounds WHERE geom && tile
),
geoms AS (
    SELECT geom FROM {src}, bounds WHERE geom && tile
    UNION
    SELECT ST_ExteriorRing(geom) AS geom FROM outer_rings
),
intersected AS (
    SELECT ST_Intersection(geom, tile) AS geom FROM geoms, bounds
),
coll AS (
    SELECT ST_Collect(geom) AS geom FROM intersected
)
INSERT INTO {dest} (x, y, rast)
    SELECT {X}, {Y}, ST_SetValue(erast, geom, 0.0) FROM emptyrast, coll;
]])
end

themepark:add_proc('gen', function()
    generate_relations_midzoom(10);
    generate_relations_midzoom(9);
    generate_relations_midzoom(8);
    generate_relations_midzoom(7);
    theme.generate_pyramid('relations', 6, 0);
end)

-- ---------------------------------------------------------------------------
