-- ---------------------------------------------------------------------------
--
-- Theme: xray
-- Topic: nodes
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

local expire_output = osm2pgsql.define_expire_output({
    minzoom = theme.midzoom_min,
    maxzoom = theme.midzoom_max,
    table = themepark.with_prefix('expire_nodes')
})

themepark:add_table({
    name = 'nodes',
    ids = { type = 'node', id_column = 'node_id', create_index = 'unique' },
    geom = 'point',
    columns = {
        { column = 'tags', type = 'jsonb', not_null = true },
    },
    expire = { { output = expire_output } }
})

themepark:add_proc('node', function(object, data)
    themepark:insert('nodes', {
        tags = object.tags,
        geom = object:as_point(),
    })
end)

themepark:add_proc('gen', theme.generate_expire('nodes'))

-- ---------------------------------------------------------------------------
