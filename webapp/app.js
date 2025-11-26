// Inicializar mapa centrado en Córdoba
const map = L.map('map').setView([-31.4201, -64.1888], 7);

// Capas base gratuitas (OpenStreetMap)
const osmLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© OpenStreetMap contributors'
});

const cartoLight = L.tileLayer('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', {
    attribution: '© CARTO © OpenStreetMap contributors'
});

const cartoDark = L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png', {
    attribution: '© CARTO © OpenStreetMap contributors'
});

// Capa por defecto
cartoDark.addTo(map);

// Control de capas base
const baseMaps = {
    "OpenStreetMap": osmLayer,
    "Carto Claro": cartoLight,
    "Carto Oscuro (Recomendado)": cartoDark
};

L.control.layers(baseMaps).addTo(map);

// Función para cargar GeoJSON desde GeoServer
async function cargarCapaGeoServer(nombreCapa) {
    const url = `http://localhost:8080/geoserver/wfs?service=WFS&version=1.0.0&request=GetFeature&typeName=${nombreCapa}&outputFormat=application/json`;
    try {
        const response = await fetch(url);
        const data = await response.json();
        return data;
    } catch (error) {
        console.error('Error cargando capa:', error);
        return null;
    }
}

// Función para crear mapa de calor
function crearMapaCalor(puntos) {
    const heatData = puntos.map(p => [p.lat, p.lon, p.intensidad || 1]);
    return L.heatLayer(heatData, {
        radius: 25,
        blur: 15,
        maxZoom: 10,
        gradient: {
            0.0: 'blue',
            0.5: 'yellow',
            1.0: 'red'
        }
    });
}

// Cargar datos de ejemplo
const puntosEjemplo = [
    {lat: -31.4201, lon: -64.1888, intensidad: 1.0, nombre: "Córdoba Capital"},
    {lat: -33.1307, lon: -64.3499, intensidad: 0.7, nombre: "Río Cuarto"},
    {lat: -32.4074, lon: -63.2429, intensidad: 0.5, nombre: "Villa María"},
    {lat: -31.4297, lon: -62.0828, intensidad: 0.4, nombre: "San Francisco"},
    {lat: -31.4241, lon: -64.4978, intensidad: 0.6, nombre: "Villa Carlos Paz"},
    {lat: -31.6667, lon: -64.4333, intensidad: 0.3, nombre: "Alta Gracia"},
    {lat: -32.1833, lon: -64.1167, intensidad: 0.4, nombre: "Río Tercero"}
];

// Agregar mapa de calor de ejemplo
const heatLayer = crearMapaCalor(puntosEjemplo);
heatLayer.addTo(map);

// Agregar marcadores
puntosEjemplo.forEach(p => {
    L.circleMarker([p.lat, p.lon], {
        radius: 8,
        fillColor: '#ff7800',
        color: '#000',
        weight: 1,
        opacity: 1,
        fillOpacity: 0.8
    }).bindPopup(`<b>${p.nombre}</b><br>Intensidad: ${p.intensidad}`).addTo(map);
});

console.log('Mapa inicializado correctamente con OpenStreetMap');
