-- ---------------------------------------------------------------------------
--
-- Theme: xray
-- Topic: relations
--
-- ---------------------------------------------------------------------------

local themepark, theme, cfg = ...

local expire_output = osm2pgsql.define_expire_output({
    minzoom = theme.midzoom_min,
    maxzoom = theme.midzoom_max,
    table = themepark.with_prefix('expire_relations')
})

-- For all valid multipolygon relations
themepark:add_table({
    name = 'rels_mp',
    ids = { type = 'relation', id_column = 'rel_id', create_index = 'unique' },
    geom = 'multipolygon',
    columns = {
        { column = 'tags', type = 'jsonb', not_null = true },
        { column = 'x_min', type = 'real', not_null = true },
        { column = 'y_min', type = 'real', not_null = true },
        { column = 'x_max', type = 'real', not_null = true },
        { column = 'y_max', type = 'real', not_null = true },
    },
    expire = { { output = expire_output } }
})

-- For all node/way members of (non-multipolygon) relations
themepark:add_table({
    name = 'rel_members',
    ids = { type = 'relation', id_column = 'rel_id', create_index = 'always' },
    geom = 'geometry',
    columns = {
        { column = 'tags', type = 'jsonb', not_null = true },
        { column = 'type', type = 'text', not_null = true },
        { column = 'x_min', type = 'real', not_null = true },
        { column = 'y_min', type = 'real', not_null = true },
        { column = 'x_max', type = 'real', not_null = true },
        { column = 'y_max', type = 'real', not_null = true },
    },
    expire = { { output = expire_output } }
})

themepark:add_proc('relation', function(object, data)
    local rel_type = object.tags.type

    if rel_type == 'multipolygon' then
        local geom = object:as_multipolygon()

        if not geom:is_null() then
            local xmin, ymin, xmax, ymax = geom:get_bbox()
            themepark:insert('rels_mp', {
                tags = object.tags,
                x_min = xmin,
                y_min = ymin,
                x_max = xmax,
                y_max = ymax,
                geom = geom,
            })
            return
        end

        -- if we can not build a valid multipolygon, fall through to generic
        -- relation handling below
    end

    local geom = object:as_geometrycollection()

    if geom then
        local xmin, ymin, xmax, ymax = geom:get_bbox()
        for sgeom in geom:geometries() do
            themepark:insert('rel_members', {
                tags = object.tags,
                type = rel_type,
                x_min = xmin,
                y_min = ymin,
                x_max = xmax,
                y_max = ymax,
                geom = sgeom,
            })
        end
    end
end)

themepark:add_proc('gen', theme.generate_expire('relations'))

-- ---------------------------------------------------------------------------
