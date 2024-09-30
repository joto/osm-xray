-- ---------------------------------------------------------------------------
--
-- XRAY Config
--
-- Configuration for the osm2pgsql Themepark framework
--
-- ---------------------------------------------------------------------------

local themepark = require('themepark')

themepark:add_theme_dir('themes')

themepark.debug = false

themepark:set_option('prefix', 'osm_')

themepark:add_topic('xray/nodes')
themepark:add_topic('xray/ways')
themepark:add_topic('xray/relations')
themepark:add_topic('xray/nodes-lowzoom')
themepark:add_topic('xray/ways-lowzoom')
themepark:add_topic('xray/relations-lowzoom')

themepark:add_topic('core/name-with-fallback', {
    keys = {
        name = { 'name', 'name:en' },
        name_en = { 'name:en', 'name' },
    }
})

themepark:add_topic('shortbread_v1_gen/boundaries')

-- ---------------------------------------------------------------------------
