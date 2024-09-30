-- ---------------------------------------------------------------------------
--
-- Theme: xray
-- Topic: ways-lowzoom
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

theme.create_lowzoom_table('ways')

local function generate_ways_midzoom(zoom)
    theme.generate_raster_midzoom('ways', 'ways', zoom, [[
geoms AS (
    SELECT CASE ST_GeometryType(geom)
               WHEN 'ST_LineString' THEN geom
               ELSE ST_ExteriorRing(geom)
           END AS geom
        FROM {src}, bounds WHERE geom && tile
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
    generate_ways_midzoom(10);
    generate_ways_midzoom(9);
    theme.generate_pyramid('ways', 8, 0);
end)

-- ---------------------------------------------------------------------------
