
const urlPrefix = 'http://test.osm2pgsql.org/';
const defaultZoom = 0;
const defaultCenter = [0.0, 0.0];
const minZoomDetail = 14;
const minZoomEditor = 15;

const Colors = {
    node: '#000000',
    way: '#000000',
    relation: [ 'interpolate', [ 'linear' ], [ 'zoom' ], 14, '#000000', 17, '#0000a0' ],
    casing: '#ffffff',
    hover: '#ffff00',
    hoverFill: '#ffff80',
    marked: '#ff0000',
    markedFill: '#ff8080',
    boundary: '#ff00ff',
}

const conditionHover = ['!=', ['feature-state', 'hover'], null];
const conditionMarked = ['==', ['feature-state', 'selection'], true];

const lineWidthBoundary2 = [ 'interpolate', [ 'exponential', 2 ], [ 'zoom' ], 1, 1, 6, 4 ];
const lineWidthBoundary4 = [ 'interpolate', [ 'exponential', 2 ], [ 'zoom' ], 5, 1.5, 8, 2 ];
const lineWidthBoundary2casing = [ 'interpolate', [ 'exponential', 2 ], [ 'zoom' ], 1, 2, 6, 6 ];
const lineWidthBoundary4casing = [ 'interpolate', [ 'exponential', 2 ], [ 'zoom' ], 5, 2.5, 8, 3 ];
const lineOpacityBoundary4 = [ 'interpolate', [ 'linear' ], [ 'zoom' ], 6, 0, 7, 1 ];

// ---------------------------------------------------------------------------

function switchActiveClassTo(element) {
    for (const sibling of element.parentNode.children) {
        sibling.classList.remove('active');
    }
    element.classList.add('active');
}

// ---------------------------------------------------------------------------

class LocationControl {

    numDigits = 5;
    halfCircumference = 20037508.34;

    map;

    locationType = 'mouse';

    coordinateSystem = 'lonlat';

    locationElement = document.getElementById('location');

    menuIDElement = document.getElementById('location-menu-id');
    menuJOSMElement = document.getElementById('location-menu-josm');
    menuOsmorgElement = document.getElementById('location-menu-osmorg');
    menuPopupElement = document.getElementById('location-menu-popup');

    mousemoveListener;
    mouseoutListener;

    constructor(map) {
        this.map = map;

        document.getElementById('location-control-type').addEventListener('click', this.switchType.bind(this));
        document.getElementById('location-control-coordinates').addEventListener('click', this.switchCoordinateSystem.bind(this));
        document.getElementById('location-copy').addEventListener('click', (event) => navigator.clipboard.writeText(this.locationElement.textContent) );

        this.map.on('move', this.updateBounds.bind(this));

        this.mousemoveListener = this.updateMouseLocation.bind(this);
        this.mouseoutListener = this.disableMouseLocation.bind(this);
        this.map.on('mousemove', this.mousemoveListener);
        this.map.on('mouseout', this.mouseoutListener);

        this.menuJOSMElement.addEventListener('click', this.loadInJOSM.bind(this));

        this.updateBounds();
    }

    async loadInJOSM(event) {
        event.preventDefault();

        // Close popup menu
        this.menuPopupElement.style.display = 'none';
        window.setTimeout( () => this.menuPopupElement.style.display = '' , 1);

        try {
            const response = await fetch(this.menuJOSMElement.getAttribute('href'));
            const text = await response.text();

            if (!response.ok || text.substring(0, 2) != 'OK') {
                throw new Error(text);
            }
        } catch (error) {
            console.log("Error when contacting JOSM: ", error);
            alert("Problem contacting JOSM. Is it running? Is remote control activated?");
        }
    }

    switchType(event) {
        this.locationType = event.target.dataset.type;
        switchActiveClassTo(event.target);
        document.getElementById('crosshair').style.display = this.locationType == 'center' ? 'block' : 'none';
        if (this.locationType == 'mouse') {
            this.map.on('mousemove', this.mousemoveListener);
            this.map.on('mouseout', this.mouseoutListener);
        } else {
            this.map.off('mousemove', this.mousemoveListener);
            this.map.off('mouseout', this.mouseoutListener);
        }
        this.updateBounds();
    }

    switchCoordinateSystem(event) {
        this.coordinateSystem = event.target.dataset.cs;
        switchActiveClassTo(event.target);
        this.updateBounds();
    }

    locationToString(loc) {
        if (this.coordinateSystem == 'lonlat') {
            loc = loc.wrap();
            return loc.lng.toFixed(this.numDigits) + ' ' + loc.lat.toFixed(this.numDigits);
        }

        loc = maplibregl.MercatorCoordinate.fromLngLat(loc);

        return (loc.x * (this.halfCircumference * 2) - this.halfCircumference).toFixed(2)
               + ' ' +
               (this.halfCircumference - loc.y * (this.halfCircumference * 2)).toFixed(2);
    }

    setLocation(loc) {
        this.locationElement.textContent = loc;
    }

    updateBounds() {
        const bounds = this.map.getBounds();
        const center = this.map.getCenter();
        const zoom = this.map.getZoom();
        const zxy = Math.round(zoom) + '/' + center.lat.toFixed(5) + '/' + center.lng.toFixed(5);

        this.menuOsmorgElement.href = 'https://www.openstreetmap.org/#map=' + zxy;

        if (zoom >= minZoomEditor) {
            this.menuIDElement.href = 'https://www.openstreetmap.org/edit#map=' + zxy;
            this.menuJOSMElement.href = 'http://localhost:8111/load_and_zoom?left=' + bounds.getWest() + '&right=' + bounds.getEast() + '&top=' + bounds.getNorth() + '&bottom=' + bounds.getSouth();
        } else {
            this.menuIDElement.href = '';
            this.menuJOSMElement.href = '';
        }

        if (this.locationType == 'mouse') {
            return;
        }

        if (this.locationType == 'center') {
            this.setLocation(this.locationToString(center));
        } else if (this.locationType == 'bounds') {
            this.setLocation(this.locationToString(bounds.getSouthWest()) +
                             ', ' +
                             this.locationToString(bounds.getNorthEast()));
        }
    }

    updateMouseLocation(event) {
        this.setLocation(this.locationToString(event.lngLat));
    }

    disableMouseLocation() {
        this.setLocation('');
    }
}

// ---------------------------------------------------------------------------

function layerFromType(objectType) {
    return objectType + 's';
}

class OSMObject {

    typesLong = { n: 'node', w: 'way', r: 'relation' };
    typesTitle = { n: 'Node', w: 'Way', r: 'Relation' };

    type;
    id;
    properties;
    bounds;

    constructor(type, id, properties) {
        this.type = type[0];
        if (id === undefined) {
            this.id = parseInt(type.slice(1));
        } else {
            this.id = id;
        }

        if (properties !== undefined) {
            this.bounds = [[properties['@xmin'], properties['@ymin']],
                           [properties['@xmax'], properties['@ymax']]];

            delete properties['@xmin'];
            delete properties['@ymin'];
            delete properties['@xmax'];
            delete properties['@ymax'];

            this.properties = properties;
        }
    }

    shortTypeId() {
        return this.type + this.id;
    }

    longType() {
        return this.typesLong[this.type];
    }

    titleType() {
        return this.typesTitle[this.type];
    }

    layer() {
        return layerFromType(this.longType());
    }

    featureIdentifier() {
        return { source: 'osm', sourceLayer: this.layer(), id: this.id };
    }

    extent() {
        if (this.type == 'n') {
            return 0;
        }
        return Math.max(this.bounds[1][0] - this.bounds[0][0],
                        this.bounds[1][1] - this.bounds[0][1]);
    }
}

// ---------------------------------------------------------------------------

class Settings {
    backgroundMaps = {
        'none': '',
        'osm': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        'osmde': 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
    };

    availableSettings = ['background', 'opacity', 'layerBoundaries', 'typeNodes', 'typeWays', 'typeRelations', 'key', 'value'];

    selectedObject = null;

    settings = {};

    elements = {};

    map;

    constructor() {
        for (const id of this.availableSettings) {
            this.elements[id] = document.getElementById('setting-' + id);
        }

        for (const el of document.forms) {
            el.addEventListener('change', this.change.bind(this));
        }

        document.getElementById('clear').addEventListener('click', (event) => {
            this.elements.key.value = '';
            this.elements.value.value = '';
            this.change(event);
        });

        this.settings = this.getSettings();

        const params = new URLSearchParams(window.location.hash.slice(1));
        for (const [p, v] of params) {
            if (p == 'b') {
                this.settings.background = v;
            }
            if (p == 'o') {
                this.settings.opacity = v;
            }
            if (p == 'l') {
                this.settings.layerBoundaries = v.includes('b');
            }
            if (p == 't') {
                this.settings.typeNodes = v.includes('n');
                this.settings.typeWays = v.includes('w');
                this.settings.typeRelations = v.includes('r');
            }
            if (p == 'k') {
                this.settings.key = v;
            }
            if (p == 'v') {
                this.settings.value = v;
            }
            if (p == 's') {
                this.selectedObject = new OSMObject(v);
            }
        }

        this.setSettings();
    }

    setMap(theMap) {
        this.map = theMap;
    }

    getBackgroundMapURL() {
        return this.backgroundMaps[this.settings.background];
    }

    getBackgroundVisibility() {
        return this.settings.background == 'none' ? 'none' : 'visible';
    }

    getBackgroundOpacity() {
        return parseInt(this.settings.opacity) / 100;
    }

    getSettings() {
        let s = {}
        for (const id of this.availableSettings) {
            const el = this.elements[id];
            s[id] = el.type == 'checkbox' ? el.checked : el.value;
        }
        return s;
    }

    setSettings() {
        for (const id of this.availableSettings) {
            const el = this.elements[id];
            if (el.type == 'checkbox') {
                el.checked = this.settings[id];
            } else {
                el.value = this.settings[id];
            }
        }
        if (this.settings.background != 'none') {
            this.elements.opacity.classList.add('enabled');
        }
    }

    hasSelection() {
        return this.selectedObject !== null;
    }

    setSelection(type, id) {
        this.selectedObject = new OSMObject(type, id);
        this.change();
        this.map.getSource('selected').setData(this.buildSelectedSource());
    }

    setParam(h, sshort, value, defaultValue) {
        if (value == defaultValue) {
            h.delete(sshort);
        } else {
            h.set(sshort, value);
        }
    }

    setHash() {
        let h = new URLSearchParams(window.location.hash.slice(1));
        this.setParam(h, 'b', this.settings.background, 'osm');
        this.setParam(h, 'o', this.settings.opacity, '50');

        const lset = (this.settings.layerBoundaries ? 'b' : '');
        this.setParam(h, 'l', lset, 'b');

        const tset = (this.settings.typeNodes ? 'n' : '') +
                     (this.settings.typeWays ? 'w' : '') +
                     (this.settings.typeRelations ? 'r' : '');

        this.setParam(h, 't', tset, 'nwr');
        this.setParam(h, 'k', this.settings.key, '');
        this.setParam(h, 'v', this.settings.value, '');

        if (this.selectedObject !== null) {
            this.setParam(h, 's', this.selectedObject.shortTypeId(), '');
        }

        window.location.hash = Array.from(h.entries()).map((v) => v[0] + '=' + v[1] ).join('&');
    }

    changeBackgroundMap(value) {
        this.settings.background = value;
        if (value == 'none') {
            this.map.setLayoutProperty('background', 'visibility', 'none');
            this.elements.opacity.classList.add('disabled');
        } else {
            const source = this.map.getSource('bg');
            source.setTiles([this.backgroundMaps[value]]);
            this.map.setLayoutProperty('background', 'visibility', 'visible');
            this.elements.opacity.classList.remove('disabled');
        }
    }

    changeBackgroundOpacity(value) {
        this.settings.opacity = value;
        this.map.setPaintProperty('background', 'raster-opacity', parseInt(value) / 100);
    }

    buildSource() {
        let params = {};
        if (this.settings.key != '') { params.key = this.settings.key };
        if (this.settings.value != '') { params.value = this.settings.value };

        const p = new URLSearchParams(params);

        let layerList = [];
        if (this.settings.typeNodes) {
            layerList.push('nodes');
        }
        if (this.settings.typeWays) {
            layerList.push('ways');
        }
        if (this.settings.typeRelations) {
            layerList.push('relations');
        }

        return urlPrefix + 'tiles/detail/' + layerList.join(',') + '/{z}/{x}/{y}.pbf?' + p.toString();
    }

    buildSelectedSource() {
        if (this.selectedObject === null) {
            return 'data:,{"type":"FeatureCollection","features":[]}';
        }
        return 'http://test.osm2pgsql.org:9000/functions/postgisftw.' + this.selectedObject.longType() + '/items?osm_id=' + this.selectedObject.id;
    }

    changeSources() {
        const url = this.buildSource(this.settings.key, this.settings.value);
        this.map.getSource('osm').setTiles([url]);

        this.map.getSource('selected').setData(this.buildSelectedSource());
    }

    setLayerVisibility(layer, value) {
        this.map.setLayoutProperty(layer, 'visibility', value ? 'visible' : 'none');
    }

    changeLayerBoundaries(value) {
        this.settings.layerBoundaries = value;
        for (const level of [2, 4]) {
            for (const t of ['core', 'casing']) {
                this.setLayerVisibility('boundaries-' + level + '-' + t, value);
            }
        }
        this.changeSources();
    }

    changeTypeNodes(value) {
        this.settings.typeNodes = value;
        this.setLayerVisibility('osm_nodes_low', value);
        this.changeSources();
    }

    changeTypeWays(value) {
        this.settings.typeWays = value;
        this.setLayerVisibility('osm_ways_low', value);
        this.changeSources();
    }

    changeTypeRelations(value) {
        this.settings.typeRelations = value;
        this.setLayerVisibility('osm_relations_low', value);
        this.changeSources();
    }

    changeFilter(key, value) {
        this.settings.key = key;
        this.settings.value = value;
        this.changeSources();
    }

    change() {
        const newSettings = this.getSettings();

        if (this.settings.background != newSettings.background) {
            this.changeBackgroundMap(newSettings.background);
        }

        if (this.settings.opacity != newSettings.opacity) {
            this.changeBackgroundOpacity(newSettings.opacity);
        }

        if (this.settings.layerBoundaries != newSettings.layerBoundaries) {
            this.changeLayerBoundaries(newSettings.layerBoundaries);
        }

        if (this.settings.typeNodes != newSettings.typeNodes) {
            this.changeTypeNodes(newSettings.typeNodes);
        }

        if (this.settings.typeWays != newSettings.typeWays) {
            this.changeTypeWays(newSettings.typeWays);
        }

        if (this.settings.typeRelations != newSettings.typeRelations) {
            this.changeTypeRelations(newSettings.typeRelations);
        }

        if (this.settings.key != newSettings.key || this.settings.value != newSettings.value) {
            this.changeFilter(newSettings.key, newSettings.value);
        }

        this.setHash();
    }
}

// ---------------------------------------------------------------------------

function buildLink(k, v) {
    if ((k == 'website' || k == 'url' || k == 'image') && v.match(/^https?:\/\//)) {
        return ['web', v];
    }
    if (k.match(/wikidata$/) && v.match(/^Q[0-9]+$/)) {
        return ['Wikidata', 'https://wikidata.org/wiki/' + v];
    }
    if (k == 'wikipedia' && v.match(/^[a-z-]{2,8}:/)) {
        const d = v.split(':');
        return ['Wikipedia', 'https://' + d[0] + '.wikipedia.org/wiki/' + d[1]];
    }
    if (k == 'mapillary' && v.match(/^[0-9]+$/)) {
        return ['Mapillary', 'https://www.mapillary.com/app/?pKey=' + v];
    }
    if (k == 'ref:bag' && v.match(/^[0-9]+$/)) {
        v = ('00000000000000' + v).substr(-16);
        return ['BAG', 'https://bagviewer.kadaster.nl/lvbag/bag-viewer/index.html#?searchQuery=' + v];
    }
    if (k == 'species' && v.match(/^[a-zA-Z -]+$/)) {
        return ['Wikispecies', 'https://species.wikimedia.org/wiki/' + v];
    }
    return [undefined, undefined];
}

function typeTitle(osmObject) {
    if (osmObject.type != 'r') {
        return osmObject.titleType();
    }

    const typeTag = osmObject.properties.type;

    const knownRelationTypes = {
        multipolygon: true,
        restriction: true,
        route: true,
        boundary: true,
        associatedStreet: true,
        public_transport: true,
        destination_sign: true,
        site: true,
        waterway: true
    };

    if (knownRelationTypes[typeTag]) {
        return typeTag.charAt(0).toUpperCase() + typeTag.substring(1) + ' Relation';
    }

    return 'Relation';
}

class ObjectStateManager {

    map;
    settings;

    listeners = { mouseleave: {}, mousemove: {}, click: null };

    hoveredObjects = { nodes: [], ways: [], relations: [] };

    objectTemplate = document.getElementById('template-object').content;
    tagTemplate = document.getElementById('template-tag').content;

    infoBoxElement = document.getElementById('info');
    overviewCountElement = document.getElementById('overview-count');
    overviewMessageElement = document.getElementById('overview-message');
    zoomMessageElement = document.getElementById('zoom-message');

    currentSelected = 0;

    locked = false;

    enabled = false;

    constructor(map, settings) {
        this.map = map;
        this.settings = settings;

        for (const objectType of ['node', 'way', 'relation']) {
            this.listeners.mousemove[objectType] = this.onMousemove.bind(this, objectType);
            this.listeners.mouseleave[objectType] = this.onMouseleave.bind(this, objectType);
        }
        this.listeners.click = this.toggleLock.bind(this);
        this.listeners.keyup = this.onKeyup.bind(this);

        if (this.map.getZoom() >= minZoomDetail) {
            this.enable();
            this.enableTagFilter();
        } else {
            this.disable();
            this.disableTagFilter();
        }

        this.map.on('zoomend', this.zoomEnd.bind(this));
        this.map.on('wheel', this.wheelOnMap.bind(this));
        this.infoBoxElement.addEventListener('wheel', this.wheelOnInfo.bind(this));
        document.addEventListener('keyup', this.listeners.keyup);
    }

    prevNextSelected(direction) {
        if (direction > 0) {
            if (this.currentSelected < this.infoBoxElement.children.length) {
                this.updateHovered(this.currentSelected + 1);
            }
        } else if (direction < 0) {
            if (this.currentSelected > 1) {
                this.updateHovered(this.currentSelected - 1);
            }
        }
    }

    wheelOnMap(event) {
        if (event.originalEvent.shiftKey) {
            event.preventDefault();
            this.prevNextSelected(event.originalEvent.deltaY);
        }
    }

    wheelOnInfo(event) {
        if (event.shiftKey) {
            event.preventDefault();
            this.prevNextSelected(event.deltaY);
        }
    }

    allHoveredObjects() {
        return this.hoveredObjects.nodes.concat(this.hoveredObjects.ways, this.hoveredObjects.relations);
    }

    countSelections() {
        return this.hoveredObjects.nodes.length +
                   this.hoveredObjects.ways.length +
                   this.hoveredObjects.relations.length;
    }

    enable() {
        this.enabled = true;
        this.zoomMessageElement.classList.remove('show');
        for (const objectType of ['node', 'way', 'relation']) {
            this.map.on('mousemove', objectType + 's-casing', this.listeners.mousemove[objectType]);
            this.map.on('mouseleave', objectType + 's-casing', this.listeners.mouseleave[objectType]);
        }
        this.map.on('click', this.listeners.click);
    }

    disable() {
        this.enabled = false;
        this.zoomMessageElement.classList.add('show');
        for (const objectType of ['node', 'way', 'relation']) {
            this.map.off('mousemove', objectType + 's-casing', this.listeners.mousemove[objectType]);
            this.map.off('mouseleave', objectType + 's-casing', this.listeners.mouseleave[objectType]);
        }
        this.map.off('click', this.listeners.click);
    }

    enableTagFilter() {
        document.getElementById('filter').classList.add('enabled');
        document.getElementById('settings-keyvalue-set').enabled = true;
    }

    disableTagFilter() {
        document.getElementById('filter').classList.remove('enabled');
        document.getElementById('settings-keyvalue-set').enabled = false;
    }

    zoomEnd() {
        const labelStyle = document.getElementById('setting-typeRelations-label').style;
        const z = Math.min(Math.max(this.map.getZoom(), 14), 17);
        const blueValue = ((z - 14) / 3) * 0xa0;
        labelStyle.color = 'rgb(0, 0, ' + blueValue + ')';

        if (this.map.getZoom() >= minZoomDetail) {
            if (!this.enabled) {
                this.enable();
            }
            if (this.countSelections() > 0) {
                this.showOverviewMessageLocked();
            }
            this.enableTagFilter();
        } else {
            if (this.locked) {
                this.unlock();
            }
            if (this.enabled) {
                this.disable();
            }
            if (this.countSelections() > 0) {
                this.showOverviewMessageZoomIn();
            }
            this.disableTagFilter();
        }
    }

    lock() {
        this.locked = true;
        this.overviewMessageElement.textContent = '🔒 (use Esc key or click to clear selection)';
    }

    unlock() {
        this.locked = false;
        this.overviewCountElement.textContent = '';
        this.overviewMessageElement.textContent = '';
        for (const objectType of ['node', 'way', 'relation']) {
            this.clearHovered(objectType);
        }
        this.updateInfoBox();
    }

    toggleLock() {
        if (this.locked) {
            this.unlock();
        } else if (this.countSelections() > 0) {
            this.lock();
        }
    }

    updateHovered(num) {
        this.currentSelected = num;

        this.setSelected(num);

        const children = this.infoBoxElement.children;
        for (const child of children) {
            child.classList.remove('active');
        }
        children[num - 1].classList.add('active');
        children[num - 1].scrollIntoView({ behavior: 'smooth', block: 'center'});
    }

    onKeyup(event) {
        if (event.key == 'Escape') {
            event.preventDefault();
            this.unlock();
            return;
        }
        if (event.key == 'PageUp') {
            event.preventDefault();
            this.prevNextSelected(-1);
            return;
        }
        if (event.key == 'PageDown') {
            event.preventDefault();
            this.prevNextSelected(1);
            return;
        }
    }

    zoomTo(osmObject, n) {
        this.updateHovered(n);
        if (osmObject.type == 'n') {
            this.map.flyTo({center: osmObject.coordinates, zoom: 18});
        } else {
            this.map.fitBounds(osmObject.bounds, { padding: 40, maxZoom: 18 });
        }
    }

    fillInfo(num, osmObject) {
        const objectClone = this.objectTemplate.cloneNode(true);

        const numElement = objectClone.querySelector('.num');
        numElement.textContent = num;
        numElement.addEventListener('click', (event) => {
            if (event.ctrlKey) {
                event.preventDefault();
                this.singleSelected(osmObject);
            } else {
                this.updateHovered(num);
            }
        });

        objectClone.querySelector('.type').textContent = typeTitle(osmObject);

        const objectLink = objectClone.querySelector('h2 a');
        objectLink.textContent = osmObject.id;
        objectLink.href += osmObject.longType() + '/' + osmObject.id;

        const toBounds = objectClone.querySelector('h2 .to-bounds');
        if (osmObject.extent() < 0.04) {
            toBounds.addEventListener('click', this.zoomTo.bind(this, osmObject, num));
        } else {
            toBounds.style.color = '#d0d0d0';
            toBounds.style.cursor = 'not-allowed';
        }

        const tbody = objectClone.querySelector('tbody');

        const sortedPropertyKeys = Object.keys(osmObject.properties).filter((k) => k != 'node_id' && k != 'way_id').sort((a,b) => a.localeCompare(b))

        sortedPropertyKeys.forEach(k => {
            const v = osmObject.properties[k];
            const tagClone = this.tagTemplate.cloneNode(true).firstElementChild;
            tagClone.dataset.key = k;
            tagClone.dataset.value = v;
            tagClone.querySelector('.tag-key span').textContent = k.replaceAll(':', ':\u200B'); // allow word break on colons
            tagClone.querySelector('.tag-value span').textContent = v;
            tagClone.querySelector('.kvmenu-taginfo-key').href += k;
            tagClone.querySelector('.kvmenu-taginfo-tag').href += k + '=' + v;
            tagClone.querySelector('.kvmenu-wiki-key').href += k;
            tagClone.querySelector('.kvmenu-wiki-tag').href += k + '=' + v;
            const [type, link] = buildLink(k, v);
            if (type) {
                tagClone.querySelector('.kvmenu-web').href = link;
                tagClone.querySelector('.kvmenu-web span').textContent = type;
            } else {
                tagClone.querySelector('.kvmenu-web').parentNode.remove();
            }
            const kvmenu = tagClone.querySelector('.kvmenu');
            tagClone.addEventListener('click', (event) => {
                const rect = tagClone.getBoundingClientRect();
                kvmenu.style.left = Math.min(tagClone.clientWidth - 140 - 2, event.clientX - rect.left - 2) + 'px';
                tagClone.classList.add('clicked');
            });
            tagClone.addEventListener('mouseleave', (event) => { tagClone.classList.remove('clicked'); } );
            tbody.appendChild(tagClone);
        });

        this.infoBoxElement.appendChild(objectClone);

        for (const el of document.querySelectorAll('.kvmenu-filter-key')) {
            el.addEventListener('click', (event) => {
                const data = el.closest('tr').dataset;
                document.getElementById('setting-key').value = data.key;
                document.getElementById('setting-value').value = '';
                this.settings.change();
            });
        }

        for (const el of document.querySelectorAll('.kvmenu-filter-tag')) {
            el.addEventListener('click', (event) => {
                const data = el.closest('tr').dataset;
                document.getElementById('setting-key').value = data.key;
                document.getElementById('setting-value').value = data.value;
                this.settings.change();
            });
        }
    }

    showOverviewMessageEmpty() {
        this.overviewMessageElement.textContent = '';
    }

    showOverviewMessageLocked() {
        this.overviewMessageElement.textContent = '🔓 (click to lock selection)';
    }

    showOverviewMessageZoomIn() {
        this.overviewMessageElement.textContent = '(zoom in to show selection on map)';
    }

    updateInfoBox() {
        this.infoBoxElement.innerHTML = '';

        for (const [n, obj] of this.allHoveredObjects().entries()) {
            this.fillInfo(n + 1, obj);
        }

        const num = this.countSelections();
        if (num > 0) {
            this.overviewCountElement.textContent = 'Selected: ' + num;
            this.showOverviewMessageLocked();
        } else {
            this.overviewCountElement.textContent = '';
            this.showOverviewMessageEmpty();
        }
    }

    setSelected(num) {
        for (const [n, obj] of this.allHoveredObjects().entries()) {
            this.map.setFeatureState(obj.featureIdentifier(), {selection: n == num - 1});
        }
    }

    clearHovered(objectType) {
        this.hoveredObjects[objectType + 's'] = [];
        this.map.removeFeatureState({
            source: 'osm',
            sourceLayer: objectType + 's',
        });
    }

    singleSelected(osmObject) {
        this.clearHovered('node');
        this.clearHovered('way');
        this.clearHovered('relation');
        this.hoveredObjects[osmObject.longType() + 's'].push(osmObject);
        this.updateInfoBox();
        this.updateHovered(1);
    }

    onMousemove(objectType, event) {
        if (this.locked) {
            return;
        }

        if (event.features.length > 0) {
            this.map.getCanvas().style.cursor = 'pointer';
        }

        this.clearHovered(objectType);

        const featureList = event.features;
        featureList.sort( (a, b) => a.id - b.id );

        let lastid = null;
        for (const f of featureList) {
            if (lastid === null || lastid != f.id) {
                const osmObject = new OSMObject(objectType, f.id, f.properties);
                if (objectType == 'node') {
                    osmObject.coordinates = f.geometry.coordinates;
                }
                this.hoveredObjects[objectType + 's'].push(osmObject);
                this.map.setFeatureState(osmObject.featureIdentifier(), {hover: true});
            }
            lastid = f.id;
        }

        this.updateInfoBox();
        this.updateHovered(1);
    }

    onMouseleave(objectType, event) {
        if (this.locked) {
            return;
        }
        this.clearHovered(objectType);
        this.updateInfoBox();
        this.map.getCanvas().style.cursor = '';
    }

}

let settings;
let locationControl;
let map;
let stateManager;

window.onload = async (event) => {
    settings = new Settings();

    map = new maplibregl.Map({
        attributionControl: false,
        container: 'map',
        dragRotate: false,
        touchPitch: false,
        touchZoomRotate: false,
        hash: 'p',
        refreshExpiredTiles: false,
        style: {
            version: 8,
            sources: {
                bg: {
                    type: 'raster',
                    tiles: [ settings.getBackgroundMapURL() ],
                    tileSize: 256,
                    minzoom: 0,
                    maxzoom: 19
                },
                osm_nodes_low: {
                    type: 'raster',
                    tiles: [ urlPrefix + 'tiles/overview/nodes/{z}/{x}/{y}.png' ],
                    tileSize: 256,
                    minzoom: 0,
                    maxzoom: minZoomDetail - 1,
                },
                osm_ways_low: {
                    type: 'raster',
                    tiles: [ urlPrefix + 'tiles/overview/ways/{z}/{x}/{y}.png' ],
                    tileSize: 256,
                    minzoom: 0,
                    maxzoom: minZoomDetail - 1,
                },
                osm_relations_low: {
                    type: 'raster',
                    tiles: [ urlPrefix + 'tiles/overview/relations/{z}/{x}/{y}.png' ],
                    tileSize: 256,
                    minzoom: 0,
                    maxzoom: minZoomDetail - 1,
                },
                osm: {
                    type: 'vector',
                    tiles: [ settings.buildSource() ],
                    minzoom: minZoomDetail,
                    maxzoom: minZoomDetail + 4,
                },
                boundaries: {
                    type: 'vector',
                    tiles: [ urlPrefix + 'tiles/overview/boundaries/{z}/{x}/{y}.pbf' ],
                    minzoom: 0,
                    maxzoom: minZoomDetail - 1,
                },
                selected: {
                    type: 'geojson',
                    data: settings.buildSelectedSource(),
                    maxzoom: minZoomDetail - 1,
                }
            },
            layers: [
                // background map
                {
                    id: 'background',
                    type: 'raster',
                    source: 'bg',
                    layout: {
                        'visibility': settings.getBackgroundVisibility()
                    },
                    paint: {
                        'raster-opacity': settings.getBackgroundOpacity()
                    },
                },
                // raster for low zoom levels
                {
                    id: 'osm_nodes_low',
                    type: 'raster',
                    source: 'osm_nodes_low',
                    maxzoom: minZoomDetail,
                    layout: {
                        'visibility': settings.settings.typeNodes ? 'visible' : 'none',
                    },
                },
                {
                    id: 'osm_ways_low',
                    type: 'raster',
                    source: 'osm_ways_low',
                    maxzoom: minZoomDetail,
                    layout: {
                        'visibility': settings.settings.typeWays ? 'visible' : 'none',
                    },
                },
                {
                    id: 'osm_relations_low',
                    type: 'raster',
                    source: 'osm_relations_low',
                    maxzoom: minZoomDetail,
                    layout: {
                        'visibility': settings.settings.typeRelations ? 'visible' : 'none',
                    },
                },
                // line casing
                {
                    id: 'ways-casing',
                    type: 'line',
                    paint: {
                        'line-color': Colors.casing,
                        'line-width': [ 'step', [ 'zoom' ], 2, 15, 7 ],
                    },
                    'source-layer': 'ways',
                    source: 'osm',
                },
                {
                    id: 'relations-casing',
                    type: 'line',
                    paint: {
                        'line-color': Colors.casing,
                        'line-width': [ 'step', [ 'zoom' ], 2, 15, 7 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm',
                },
                {
                    id: 'ways-points-casing',
                    filter: [ '==', ['geometry-type'], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.casing,
                        'circle-radius': 3,
                    },
                    'source-layer': 'ways',
                    source: 'osm'
                },
                // line hover
                {
                    id: 'ways-hover',
                    type: 'line',
                    paint: {
                        'line-color': [ 'case', conditionHover, Colors.hover, 'transparent' ],
                        'line-width': [ 'step', [ 'zoom' ], 2, 15, 7 ],
                    },
                    'source-layer': 'ways',
                    source: 'osm',
                },
                {
                    id: 'relations-hover',
                    type: 'line',
                    paint: {
                        'line-color': [ 'case', conditionHover, Colors.hover, 'transparent' ],
                        'line-width': [ 'step', [ 'zoom' ], 2, 15, 7 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm',
                },
                {
                    id: 'ways-points-hover',
                    filter: [ '==', ['geometry-type'], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': [ 'case', conditionHover, Colors.hover, 'transparent' ],
                        'circle-radius': 3,
                    },
                    'source-layer': 'ways',
                    source: 'osm'
                },
                // line core
                {
                    id: 'ways',
                    type: 'line',
                    paint: {
                        'line-color': Colors.way,
                        'line-width': [ 'step', [ 'zoom' ], 0.5, 15, 2 ],
                    },
                    'source-layer': 'ways',
                    source: 'osm',
                },
                {
                    id: 'relations-lines',
                    filter: [ '==', [ 'geometry-type' ], 'LineString' ],
                    type: 'line',
                    paint: {
                        'line-color': Colors.relation,
                        'line-width': [ 'step', [ 'zoom' ], 0.5, 15, 2 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                {
                    id: 'relations-polygons',
                    filter: [ '==', [ 'geometry-type' ], 'Polygon' ],
                    type: 'line',
                    paint: {
                        'line-color': Colors.relation,
                        'line-width': [ 'step', [ 'zoom' ], 0.5, 15, 2 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                {
                    id: 'ways-points',
                    filter: [ '==', ['geometry-type'], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.way,
                        'circle-radius': 1,
                    },
                    'source-layer': 'ways',
                    'source': 'osm'
                },
                // point casing
                {
                    id: 'nodes-casing',
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.casing,
                        'circle-radius': [ 'step', [ 'zoom' ], 5, 15, 6 ],
                    },
                    'source-layer': 'nodes',
                    source: 'osm'
                },
                {
                    id: 'relations-nodes-casing',
                    filter: [ '==', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.casing,
                        'circle-radius': [ 'step', [ 'zoom' ], 3, 12, 6 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                // point hover
                {
                    id: 'nodes-hover',
                    type: 'circle',
                    paint: {
                        'circle-color': [ 'case', conditionHover, Colors.hover, 'transparent' ],
                        'circle-radius': [ 'step', [ 'zoom' ], 5, 15, 6 ],
                    },
                    'source-layer': 'nodes',
                    source: 'osm'
                },
                {
                    id: 'relations-nodes-hover',
                    filter: [ '==', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': [ 'case', conditionHover, Colors.hover, 'transparent' ],
                        'circle-radius': [ 'step', [ 'zoom' ], 3, 12, 6 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                // point core
                {
                    id: 'nodes',
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.node,
                        'circle-radius': [ 'step', [ 'zoom' ], 4, 15, 4 ]
                    },
                    'source-layer': 'nodes',
                    source: 'osm'
                },
                {
                    id: 'relations-nodes',
                    filter: [ '==', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.relation,
                        'circle-radius': [ 'step', [ 'zoom' ], 2, 12, 4 ]
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                // marked
                {
                    id: 'ways-polygons-marked',
                    type: 'fill',
                    filter: [ '==', [ 'geometry-type' ], 'Polygon' ],
                    paint: {
                        'fill-color': Colors.markedFill,
                        'fill-opacity': [ 'case', conditionMarked, 0.5, 0 ],
                    },
                    'source-layer': 'ways',
                    source: 'osm'
                },
                {
                    id: 'relations-polygons-marked',
                    type: 'fill',
                    filter: [ '==', [ 'geometry-type' ], 'Polygon' ],
                    paint: {
                        'fill-color': Colors.markedFill,
                        'fill-opacity': [ 'case', conditionMarked, 0.5, 0 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                {
                    id: 'ways-marked',
                    type: 'line',
                    paint: {
                        'line-color': Colors.marked,
                        'line-width': 2,
                        'line-opacity': [ 'case', conditionMarked, 1, 0 ],
                    },
                    'source-layer': 'ways',
                    source: 'osm'
                },
                {
                    id: 'ways-marked-arrow',
                    type: 'symbol',
                    layout: {
                        'symbol-placement': 'line',
                        'symbol-spacing': 100,
                        'icon-image': 'arrow',
                        'icon-size': 0.4,
                        'icon-rotate': 0,
                    },
                    paint: {
                        'icon-opacity': [ 'case', conditionMarked, 1, 0 ],
                    },
                    'source-layer': 'ways',
                    source: 'osm',
                    minzoom: 17,
                },
                {
                    id: 'relations-lines-marked',
                    type: 'line',
                    paint: {
                        'line-color': Colors.marked,
                        'line-width': 2,
                        'line-opacity': [ 'case', conditionMarked, 1, 0 ],
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                {
                    id: 'relations-nodes-marked',
                    filter: [ '==', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.marked,
                        'circle-opacity': [ 'case', conditionMarked, 1, 0 ],
                        'circle-radius': [ 'step', [ 'zoom' ], 2, 12, 4 ]
                    },
                    'source-layer': 'relations',
                    source: 'osm'
                },
                {
                    id: 'nodes-marked',
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.marked,
                        'circle-opacity': [ 'case', conditionMarked, 1, 0 ],
                        'circle-radius': [ 'step', [ 'zoom' ], 2, 12, 4 ]
                    },
                    'source-layer': 'nodes',
                    source: 'osm'
                },
                // selected
                {
                    id: 'selected-fill',
                    filter: [ '==', [ 'geometry-type' ], 'Polygon' ],
                    type: 'fill',
                    paint: {
                        'fill-color': Colors.hoverFill,
                        'fill-opacity': 0.5,
                    },
                    source: 'selected',
                    maxzoom: minZoomDetail
                },
                {
                    id: 'selected-line-casing',
                    type: 'line',
                    paint: {
                        'line-color': Colors.hover,
                        'line-width': 5,
                    },
                    source: 'selected',
                    maxzoom: minZoomDetail
                },
                {
                    id: 'selected-point-from-line-casing',
                    filter: [ '!=', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': '#ffffff',
                        'circle-radius': [ 'step', [ 'zoom' ], 5, 10, 4, 13, 3 ]
                    },
                    source: 'selected',
                    maxzoom: minZoomDetail
                },
                {
                    id: 'selected-line-core',
                    type: 'line',
                    paint: {
                        'line-color': Colors.hover,
                        'line-width': 4,
                    },
                    source: 'selected',
                    maxzoom: minZoomDetail
                },
                {
                    id: 'selected-point-from-line-core',
                    filter: [ '!=', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.hover,
                        'circle-radius': [ 'step', [ 'zoom' ], 4, 10, 3, 13, 2 ]
                    },
                    source: 'selected',
                    maxzoom: minZoomDetail
                },
                {
                    id: 'selected-point-casing',
                    filter: [ '==', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': '#ffffff',
                        'circle-radius': 5,
                    },
                    source: 'selected',
                    maxzoom: minZoomDetail
                },
                {
                    id: 'selected-point-core',
                    filter: [ '==', [ 'geometry-type' ], 'Point' ],
                    type: 'circle',
                    paint: {
                        'circle-color': Colors.hover,
                        'circle-radius': 4,
                    },
                    source: 'selected',
                    maxzoom: minZoomDetail
                },
                {
                    id: 'boundaries-2-casing',
                    type: 'line',
                    filter: [ '==', [ 'get', 'admin_level' ], 2 ],
                    layout: {
                        'line-cap': 'round',
                        'line-join': 'round',
                        'visibility': settings.settings.layerBoundaries ? 'visible' : 'none',
                    },
                    paint: {
                        'line-color': Colors.casing,
                        'line-width': lineWidthBoundary2casing,
                    },
                    'source-layer': 'boundaries',
                    source: 'boundaries',
                    minzoom: 1,
                    maxzoom: minZoomDetail
                },
                {
                    id: 'boundaries-4-casing',
                    type: 'line',
                    filter: [ '==', [ 'get', 'admin_level' ], 4 ],
                    layout: {
                        'line-cap': 'round',
                        'line-join': 'round',
                        'visibility': settings.settings.layerBoundaries ? 'visible' : 'none',
                    },
                    paint: {
                        'line-color': Colors.casing,
                        'line-width': lineWidthBoundary4casing,
                        'line-opacity': lineOpacityBoundary4,
                    },
                    'source-layer': 'boundaries',
                    source: 'boundaries',
                    minzoom: 6,
                    maxzoom: minZoomDetail
                },
                {
                    id: 'boundaries-2-core',
                    type: 'line',
                    filter: [ '==', [ 'get', 'admin_level' ], 2 ],
                    layout: {
                        'line-cap': 'round',
                        'line-join': 'round',
                        'visibility': settings.settings.layerBoundaries ? 'visible' : 'none',
                    },
                    paint: {
                        'line-color': Colors.boundary,
                        'line-width': lineWidthBoundary2,
                    },
                    'source-layer': 'boundaries',
                    source: 'boundaries',
                    minzoom: 1,
                    maxzoom: minZoomDetail
                },
                {
                    id: 'boundaries-4-core',
                    type: 'line',
                    filter: [ '==', [ 'get', 'admin_level' ], 4 ],
                    layout: {
                        'line-cap': 'round',
                        'line-join': 'round',
                        'visibility': settings.settings.layerBoundaries ? 'visible' : 'none',
                    },
                    paint: {
                        'line-color': Colors.boundary,
                        'line-width': lineWidthBoundary4,
                        'line-opacity': lineOpacityBoundary4,
                    },
                    'source-layer': 'boundaries',
                    source: 'boundaries',
                    minzoom: 6,
                    maxzoom: minZoomDetail
                },
            ]
        },

        center: defaultCenter,
        zoom: defaultZoom,
    });

    map.loadImage('arrow.png').then( (image) => map.addImage('arrow', image.data) );

    map.keyboard.disableRotation();
    map.addControl(new maplibregl.NavigationControl({ showCompass: false }), 'top-left');
    map.addControl(new maplibregl.ScaleControl({ unit: 'metric', maxWidth: 80 }));

    document.getElementById('map').addEventListener('keyup', (event) => {
        if (event.key == 't') {
            map.showTileBoundaries = !map.showTileBoundaries;
        }
    });

    const busyMessage = document.getElementById('busy-message');
    map.on('sourcedataloading', () => busyMessage.classList.add('show') );
    map.on('idle', () => busyMessage.classList.remove('show') );

    settings.setMap(map);

    locationControl = new LocationControl(map);
    stateManager = new ObjectStateManager(map, settings);
    stateManager.zoomEnd();
};

