-- ---------------------------------------------------------------------------
--
-- Theme: xray
--
-- ---------------------------------------------------------------------------

local themepark = ...

local theme = {
    lowzoom_max = 10,
    midzoom_min = 11,
    midzoom_max = 13,
    prefix = themepark.options.prefix or '',
}

theme.create_lowzoom_table = function(table_type)
    for zoom = 0, theme.lowzoom_max do
        local name = table_type .. '_z' .. zoom
        themepark:add_table({
            name = name,
            ids_type = 'tile',
            columns = {
                { column = 'rast', sql_type = 'raster', not_null = true },
            }
        })
    end
end

local function add_raster_constraints(table_name)
    if osm2pgsql.mode == 'create' then
        osm2pgsql.run_sql({
            description = 'Add constraints on ' .. table_name,
            sql = "SELECT AddRasterConstraints('" .. table_name .. "', 'rast');"
        })
    end
end

theme.generate_raster_midzoom = function(src_table, dest_table, zoom, geom_sql)
    local sql = [[
WITH
bounds AS (
    SELECT ST_TileEnvelope({ZOOM}, {X}, {Y}) AS tile
),
dim AS (
    SELECT ST_XMin(tile) AS xmin,
           ST_YMax(tile) AS ymin,
           (40075016.685578488::float8 / (2 ^ {ZOOM})::float8) / {extent} AS wh
           FROM bounds
),
emptyrast AS (
    SELECT ST_AddBand(ST_MakeEmptyRaster({extent}, {extent},
                                         xmin, ymin, wh, -wh,
                                         0.0, 0.0, 3857),
                      '8BUI', 255.0, 255.0) AS erast FROM dim
),
]]
    .. geom_sql .. [[
]]

    local src_table_name = theme.prefix .. src_table
    local dest_table_name = theme.prefix .. dest_table .. '_z' .. zoom
    osm2pgsql.run_gen('tile-sql', {
        name = dest_table .. '-raster-z' .. zoom,
        src_table = src_table_name,
        dest_table = dest_table_name,
        extent = 1024,
        zoom = zoom,
        expire_list = themepark.with_prefix('expire_' .. dest_table),
        sql = sql
    })

    add_raster_constraints(dest_table_name)
end

theme.generate_pyramid = function(id, maxzoom, minzoom)
    local pyramid_step_sql = [[
    WITH
    bounds AS (
        SELECT ST_TileEnvelope({ZOOM} + 1, {X} * 2, {Y} * 2) AS tile
        UNION
        SELECT ST_TileEnvelope({ZOOM} + 1, {X} * 2, {Y} * 2 + 1) AS tile
        UNION
        SELECT ST_TileEnvelope({ZOOM} + 1, {X} * 2 + 1, {Y} * 2) AS tile
        UNION
        SELECT ST_TileEnvelope({ZOOM} + 1, {X} * 2 + 1, {Y} * 2 + 1) AS tile
    ),
    dim AS (
        SELECT ST_XMin(tile) AS xmin,
               ST_YMax(tile) AS ymin,
               (40075016.685578488::float8 / (2 ^ ({ZOOM} + 1))::float8) / {extent} AS wh
               FROM bounds
    ),
    emptyrast AS (
        SELECT ST_AddBand(ST_MakeEmptyRaster({extent}, {extent},
                                             xmin, ymin, wh, -wh,
                                             0.0, 0.0, 3857),
                          '8BUI', 255.0, 255.0) AS erast FROM dim
    ),
    inputs AS (
        SELECT {raster_column} AS rast
            FROM {src_table}
            WHERE x BETWEEN {X} * 2 AND {X} * 2 + 1
              AND y BETWEEN {Y} * 2 AND {Y} * 2 + 1
        UNION
        SELECT erast FROM emptyrast
    ),
    merged AS (
        SELECT ST_Resize(ST_Union(rast, 'SUM'), {extent}, {extent}, 'Cubic') AS rast FROM inputs
    )
    INSERT INTO {dest_table} (x, y, rast)
        SELECT {X}, {Y}, rast FROM merged WHERE rast IS NOT NULL
    ]]

    for zoom = maxzoom, minzoom, -1 do
        local src_table_name = theme.prefix .. id .. '_z' .. (zoom + 1)
        local dest_table_name = theme.prefix .. id .. '_z' .. zoom
        osm2pgsql.run_gen('tile-sql', {
            name = id .. '-pyramid-z' .. zoom,
            src_table = src_table_name,
            dest_table = dest_table_name,
            extent = 1024,
            raster_column = 'rast',
            zoom = zoom,
            expire_list = themepark.with_prefix('expire_' .. id),
            sql = pyramid_step_sql
        })

        add_raster_constraints(dest_table_name)
    end
end

if osm2pgsql.mode == 'append' then
    theme.generate_expire = function(type)
        return function()
            osm2pgsql.run_sql({
                description = 'Expire tile cache (midzoom) for ' .. type,
                transaction = true,
                sql = { themepark.expand_template(
                        "DELETE FROM tile_cache c USING {prefix}expire_"
                            .. type .. " e WHERE c.layer='"
                            .. type .. "' AND c.z = e.zoom AND c.x = e.x AND c.y = e.y"),
                        themepark.expand_template("TRUNCATE {prefix}expire_" .. type)
                },
                if_has_rows = "SELECT tablename FROM pg_tables WHERE tablename='tile_cache'",
            })
        end
    end
else
    theme.generate_expire = function(type)
    end
end

return theme

-- ---------------------------------------------------------------------------
