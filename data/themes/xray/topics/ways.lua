-- ---------------------------------------------------------------------------
--
-- Theme: xray
-- Topic: ways
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

local expire_output = osm2pgsql.define_expire_output({
    minzoom = theme.midzoom_min,
    maxzoom = theme.midzoom_max,
    table = themepark.with_prefix('expire_ways')
})

themepark:add_table({
    name = 'ways',
    ids = { type = 'way', id_column = 'way_id', create_index = 'unique' },
    geom = 'geometry',
    columns = {
        { column = 'tags', type = 'jsonb', not_null = true },
        { column = 'closed', type = 'bool', not_null = true },
    },
    expire = { { output = expire_output } }
})

themepark:add_proc('way', function(object, data)
    -- try building a polygon and fall back to linestring if that doesn't work
    local geom = object:as_polygon()

    if geom:is_null() then
        geom = object:as_linestring()
    end

    themepark:insert('ways', {
        tags = object.tags,
        closed = object.is_closed,
        geom = geom,
    })
end)

themepark:add_proc('gen', theme.generate_expire('ways'))

-- ---------------------------------------------------------------------------
