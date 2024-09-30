-- ---------------------------------------------------------------------------
--
-- Theme: xray
-- Topic: nodes-lowzoom
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

theme.create_lowzoom_table('nodes')

local function generate_nodes_midzoom(zoom)
    theme.generate_raster_midzoom('nodes', 'nodes', zoom, [[
geoms AS (
    SELECT geom FROM {src}, bounds WHERE geom && tile
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
    generate_nodes_midzoom(10);
    generate_nodes_midzoom(9);
    generate_nodes_midzoom(8);
    generate_nodes_midzoom(7);
    theme.generate_pyramid('nodes', 6, 0);
end)

-- ---------------------------------------------------------------------------
