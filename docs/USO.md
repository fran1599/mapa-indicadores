# Guía de Uso del Sistema

Esta guía explica cómo utilizar el sistema de visualización de indicadores de adicciones para la Provincia de Córdoba. Incluye instrucciones para cargar datos, crear visualizaciones y ejecutar análisis espaciales.

## Índice

1. [Acceso a los Servicios](#acceso-a-los-servicios)
2. [Datos de Córdoba Incluidos](#datos-de-córdoba-incluidos)
3. [Geocodificación de Localidades](#geocodificación-de-localidades)
4. [Cargar Datos Geográficos](#cargar-datos-geográficos)
5. [Usar Jupyter + Leafmap (Recomendado)](#usar-jupyter--leafmap-recomendado)
6. [Usar la Webapp Leaflet](#usar-la-webapp-leaflet)
7. [Publicar Capas en GeoServer](#publicar-capas-en-geoserver)
8. [Consultas Espaciales en PostGIS](#consultas-espaciales-en-postgis)
9. [Ejemplos de Análisis para Córdoba](#ejemplos-de-análisis-para-córdoba)

---

## Acceso a los Servicios

### pgAdmin (Administración de Base de Datos)

1. Abrir http://localhost:5050
2. Iniciar sesión:
   - Email: `admin@local.dev`
   - Contraseña: `admin123`
3. Agregar servidor PostgreSQL:
   - Clic derecho en "Servers" → "Register" → "Server"
   - Pestaña "General": Nombre: `GIS Adicciones`
   - Pestaña "Connection":
     - Host: `postgis` (nombre del contenedor)
     - Puerto: `5432`
     - Base de datos: `gis_adicciones`
     - Usuario: `gisuser`
     - Contraseña: `gispassword`

### GeoServer (Servidor de Mapas)

1. Abrir http://localhost:8080/geoserver
2. Iniciar sesión:
   - Usuario: `admin`
   - Contraseña: `admin123`

### Jupyter + Leafmap (Recomendado)

1. Abrir http://localhost:8888
2. No requiere token ni contraseña (acceso directo)
3. Abrir la carpeta `work/` para ver los notebooks
4. 100% gratuito, usa OpenStreetMap como mapa base

### MapStore (Alternativa sin Mapbox)

1. Abrir http://localhost:8082
2. No requiere autenticación ni API keys externas

### Webapp Leaflet

1. Abrir http://localhost:8083
2. No requiere autenticación ni API keys
3. Funciona 100% con OpenStreetMap

---

## Datos de Córdoba Incluidos

El sistema incluye datos geográficos precargados de la Provincia de Córdoba:

### Departamentos (26)

Consultar los departamentos cargados:

```sql
SELECT nombre, codigo FROM zonas_geograficas 
WHERE tipo = 'departamento' AND codigo_padre = 'AR-X'
ORDER BY nombre;
```

### Regiones Sanitarias (14)

```sql
SELECT nombre, codigo FROM zonas_geograficas 
WHERE tipo = 'region_sanitaria'
ORDER BY codigo;
```

### Localidades (55+)

```sql
SELECT nombre, departamento, poblacion, latitud, longitud 
FROM localidades 
ORDER BY poblacion DESC;
```

---

## Geocodificación de Localidades

El script `geocodificar.py` permite agregar coordenadas geográficas a archivos CSV:

### Uso Básico

```bash
# Geocodificar archivo CSV
python scripts/geocodificar.py \
    --input datos.csv \
    --columna localidad \
    --output datos_geo.csv
```

### Opciones Disponibles

```bash
# Ver todas las localidades en la base de datos local
python scripts/geocodificar.py --listar-localidades

# Usar solo base de datos local (sin consultas a Internet)
python scripts/geocodificar.py \
    --input datos.csv \
    --columna ciudad \
    --output datos_geo.csv \
    --solo-local

# Usar delimitador diferente (ej: punto y coma)
python scripts/geocodificar.py \
    --input datos.csv \
    --columna localidad \
    --output datos_geo.csv \
    --delimitador ";"
```

### Ejemplo de Archivo de Entrada

```csv
id,paciente,localidad,fecha
1,Juan Pérez,Córdoba,2024-01-15
2,María García,Río Cuarto,2024-01-16
3,Carlos López,Villa María,2024-01-17
```

### Resultado de Salida

```csv
id,paciente,localidad,fecha,latitud,longitud,fuente_geocodificacion
1,Juan Pérez,Córdoba,2024-01-15,-31.4201,-64.1888,local
2,María García,Río Cuarto,2024-01-16,-33.1307,-64.3499,local
3,Carlos López,Villa María,2024-01-17,-32.4074,-63.2429,local
```

---

## Cargar Datos Geográficos

### Desde archivo GeoJSON

```bash
# Usando ogr2ogr (si está instalado)
ogr2ogr -f "PostgreSQL" \
  "PG:host=localhost port=5432 dbname=gis_adicciones user=gisuser password=gispassword" \
  tu_archivo.geojson \
  -nln nombre_tabla \
  -append

# Usando Docker
docker run --rm -v $(pwd):/data osgeo/gdal:alpine-normal-latest \
  ogr2ogr -f "PostgreSQL" \
  "PG:host=host.docker.internal port=5432 dbname=gis_adicciones user=gisuser password=gispassword" \
  /data/tu_archivo.geojson \
  -nln nombre_tabla
```

### Desde archivo Shapefile

```bash
# Usando shp2pgsql
docker exec -i gis_postgis shp2pgsql -s 4326 -I /ruta/archivo.shp nombre_tabla | \
  docker exec -i gis_postgis psql -U gisuser -d gis_adicciones
```

### Insertar datos manualmente

```sql
-- Insertar una zona geográfica
INSERT INTO zonas_geograficas (codigo, nombre, tipo, geom) VALUES (
  'AR-B-001',
  'La Plata',
  'localidad',
  ST_SetSRID(ST_GeomFromGeoJSON('{
    "type": "Polygon",
    "coordinates": [[[-57.98, -34.95], [-57.98, -34.85], [-57.88, -34.85], [-57.88, -34.95], [-57.98, -34.95]]]
  }'), 4326)
);

-- Insertar un indicador con ubicación
INSERT INTO indicadores_adicciones (zona_id, fecha, tipo_indicador, valor, descripcion, ubicacion) VALUES (
  1,
  '2024-03-01',
  'consumo',
  45.5,
  'Casos reportados en marzo',
  ST_SetSRID(ST_MakePoint(-58.3816, -34.6037), 4326)
);

-- Insertar un centro de atención
INSERT INTO centros_atencion (nombre, direccion, telefono, tipo, ubicacion, zona_id) VALUES (
  'Centro de Atención Norte',
  'Av. Libertador 1234',
  '011-4555-1234',
  'ambulatorio',
  ST_SetSRID(ST_MakePoint(-58.42, -34.58), 4326),
  1
);
```

---

## Usar Jupyter + Leafmap (Recomendado)

Jupyter + Leafmap es la forma más potente y flexible de crear visualizaciones de mapas. Es 100% gratuito y usa OpenStreetMap como mapa base.

### Acceder a Jupyter

1. Abrir http://localhost:8888
2. No requiere token ni contraseña (acceso directo)
3. Navegar a la carpeta `work/` para ver los notebooks disponibles

### Notebooks Disponibles

| Notebook | Descripción |
|----------|-------------|
| `01_inicio_rapido.ipynb` | Introducción a Leafmap, crear mapas básicos |
| `02_mapa_calor.ipynb` | Crear mapas de calor con indicadores |
| `03_conexion_postgis.ipynb` | Conectar y consultar datos desde PostGIS |
| `04_cruce_datos.ipynb` | Análisis cruzando indicadores con datos censales |

### Crear un Mapa Básico

```python
import leafmap

# Crear mapa centrado en Córdoba
m = leafmap.Map(center=[-31.4201, -64.1888], zoom=7)
m
```

### Cargar GeoJSON

```python
import geopandas as gpd

# Cargar departamentos de Córdoba
departamentos = gpd.read_file('/home/jovyan/data/cordoba/departamentos.geojson')

# Agregar al mapa
m = leafmap.Map(center=[-31.4201, -64.1888], zoom=7)
m.add_gdf(departamentos, layer_name="Departamentos de Córdoba")
m
```

### Crear Mapa de Calor

```python
import pandas as pd

# Cargar datos de indicadores
datos = pd.read_csv('/home/jovyan/data/ejemplo_indicadores.csv')

# Crear mapa con heatmap
m = leafmap.Map(center=[-31.4201, -64.1888], zoom=7)
m.add_heatmap(
    data=datos,
    latitude="latitud",
    longitude="longitud",
    value="valor",
    name="Mapa de Calor",
    radius=25
)
m
```

### Conectar con PostGIS

```python
from sqlalchemy import create_engine
import geopandas as gpd

# Conexión a la base de datos
engine = create_engine('postgresql://gisuser:gispassword@postgis:5432/gis_adicciones')

# Cargar datos espaciales
query = "SELECT * FROM zonas_geograficas WHERE tipo = 'departamento'"
zonas = gpd.read_postgis(query, engine, geom_col='geom')

# Visualizar en mapa
m = leafmap.Map(center=[-31.4201, -64.1888], zoom=7)
m.add_gdf(zonas, layer_name="Departamentos")
m
```

### Exportar Mapa como HTML

```python
# Guardar mapa interactivo como HTML
m.to_html('/home/jovyan/work/mi_mapa.html')
```

---

## Usar la Webapp Leaflet

La Webapp Leaflet es una alternativa simple para visualizar mapas sin necesidad de programar. Usa OpenStreetMap y CARTO como proveedores de tiles gratuitos.

### Acceder a la Webapp

1. Abrir http://localhost:8083
2. El mapa se cargará automáticamente centrado en Córdoba
3. Un mapa de calor de ejemplo se muestra por defecto

### Cambiar Capa Base

En la esquina superior derecha encontrarás un control de capas:

- **OpenStreetMap**: Mapa base estándar
- **Carto Claro**: Estilo minimalista claro
- **Carto Oscuro (Recomendado)**: Ideal para mapas de calor, mejor contraste

### Interactuar con el Mapa

- **Zoom**: Usar scroll del mouse o botones +/-
- **Pan**: Arrastrar el mapa
- **Ver detalles**: Clic en los marcadores circulares

### Personalizar la Webapp

Para agregar tus propios datos, edita el archivo `webapp/app.js`:

```javascript
// Agregar nuevos puntos al mapa de calor
const nuevosPuntos = [
    {lat: -31.4201, lon: -64.1888, intensidad: 1.0, nombre: "Mi Localidad"},
    // Agregar más puntos...
];

// Crear capa de calor
const miHeatLayer = crearMapaCalor(nuevosPuntos);
miHeatLayer.addTo(map);
```

### Cargar Datos desde GeoServer

La webapp incluye una función para cargar capas desde GeoServer:

```javascript
// Cargar capa WFS desde GeoServer
const datos = await cargarCapaGeoServer('adicciones:zonas_geograficas');
if (datos) {
    L.geoJSON(datos).addTo(map);
}
```

### Crear Mapa de Calor Personalizado

```javascript
// Función para crear mapa de calor
const heatLayer = L.heatLayer(misDatos, {
    radius: 25,      // Radio del punto de calor
    blur: 15,        // Difuminado
    maxZoom: 10,     // Zoom máximo
    gradient: {
        0.0: 'blue',
        0.5: 'yellow',
        1.0: 'red'
    }
});
heatLayer.addTo(map);
```

---

## Publicar Capas en GeoServer

### Paso 1: Crear Workspace

1. En GeoServer, ir a "Workspaces" → "Add new workspace"
2. Completar:
   - Name: `adicciones`
   - Namespace URI: `http://localhost/adicciones`
3. Clic en "Submit"

### Paso 2: Crear Store (Conexión a PostGIS)

1. Ir a "Stores" → "Add new Store"
2. Seleccionar "PostGIS"
3. Completar:
   - Workspace: `adicciones`
   - Data Source Name: `postgis_adicciones`
   - Host: `postgis`
   - Port: `5432`
   - Database: `gis_adicciones`
   - Schema: `public`
   - User: `gisuser`
   - Password: `gispassword`
4. Clic en "Save"

### Paso 3: Publicar Capas

1. Ir a "Layers" → "Add new layer"
2. Seleccionar el store `adicciones:postgis_adicciones`
3. Clic en "Publish" junto a la tabla deseada (ej: `zonas_geograficas`)
4. En la pestaña "Data":
   - Verificar SRS: `EPSG:4326`
   - Clic en "Compute from data" para Bounding Boxes
5. Clic en "Save"

### Paso 4: Previsualizar Capa

1. Ir a "Layer Preview"
2. Buscar la capa publicada
3. Clic en "OpenLayers" para ver en el navegador

### URLs de los servicios WMS/WFS

```
# WMS (visualización de imágenes)
http://localhost:8080/geoserver/adicciones/wms?service=WMS&version=1.1.0&request=GetCapabilities

# WFS (datos vectoriales)
http://localhost:8080/geoserver/adicciones/wfs?service=WFS&version=1.1.0&request=GetCapabilities

# Obtener capa como GeoJSON
http://localhost:8080/geoserver/adicciones/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=adicciones:zonas_geograficas&outputFormat=application/json
```

---

## Consultas Espaciales en PostGIS

### Conectar a la base de datos

```bash
# Desde terminal
docker exec -it gis_postgis psql -U gisuser -d gis_adicciones
```

### Consultas básicas

```sql
-- Ver todas las provincias
SELECT codigo, nombre FROM zonas_geograficas WHERE tipo = 'provincia';

-- Contar indicadores por tipo
SELECT tipo_indicador, COUNT(*) as cantidad, SUM(valor) as total
FROM indicadores_adicciones
GROUP BY tipo_indicador;

-- Indicadores del último mes
SELECT z.nombre, i.tipo_indicador, i.valor, i.fecha
FROM indicadores_adicciones i
JOIN zonas_geograficas z ON i.zona_id = z.id
WHERE i.fecha >= CURRENT_DATE - INTERVAL '30 days'
ORDER BY i.fecha DESC;
```

### Consultas espaciales

```sql
-- Encontrar zonas que contienen un punto específico
SELECT nombre, tipo 
FROM zonas_geograficas 
WHERE ST_Contains(geom, ST_SetSRID(ST_MakePoint(-58.3816, -34.6037), 4326));

-- Indicadores dentro de un radio de 50km de un punto
SELECT i.*, ST_Distance(
  i.ubicacion::geography, 
  ST_SetSRID(ST_MakePoint(-58.3816, -34.6037), 4326)::geography
) / 1000 as distancia_km
FROM indicadores_adicciones i
WHERE ST_DWithin(
  i.ubicacion::geography,
  ST_SetSRID(ST_MakePoint(-58.3816, -34.6037), 4326)::geography,
  50000  -- 50 km en metros
)
ORDER BY distancia_km;

-- Calcular área de cada provincia en km²
SELECT nombre, 
       ST_Area(geom::geography) / 1000000 as area_km2
FROM zonas_geograficas 
WHERE tipo = 'provincia'
ORDER BY area_km2 DESC;

-- Centroide de cada zona
SELECT nombre, 
       ST_X(ST_Centroid(geom)) as longitud,
       ST_Y(ST_Centroid(geom)) as latitud
FROM zonas_geograficas;
```

---

## Ejemplos de Análisis para Córdoba

### Consultar indicadores por localidad de Córdoba

```sql
-- Indicadores agrupados por localidad
SELECT 
  l.nombre as localidad,
  l.departamento,
  i.tipo_indicador,
  COUNT(i.id) as cantidad,
  SUM(i.valor) as total
FROM indicadores_adicciones i
JOIN localidades l ON i.localidad_id = l.id
GROUP BY l.nombre, l.departamento, i.tipo_indicador
ORDER BY total DESC;
```

### Análisis por departamento de Córdoba

```sql
-- Resumen de indicadores por departamento
SELECT 
  z.nombre as departamento,
  dc.poblacion_total,
  COUNT(i.id) as total_indicadores,
  SUM(i.valor) as suma_valores,
  ROUND((SUM(i.valor) / NULLIF(dc.poblacion_total, 0) * 10000)::numeric, 2) as tasa_por_10000
FROM zonas_geograficas z
LEFT JOIN datos_censo dc ON z.id = dc.zona_id AND dc.anio = 2022
LEFT JOIN indicadores_adicciones i ON z.id = i.zona_id
WHERE z.tipo = 'departamento' AND z.codigo_padre = 'AR-X'
GROUP BY z.nombre, dc.poblacion_total
ORDER BY tasa_por_10000 DESC NULLS LAST;
```

### Análisis por región sanitaria

```sql
-- Indicadores por región sanitaria
SELECT 
  z.nombre as region_sanitaria,
  i.tipo_indicador,
  COUNT(i.id) as cantidad,
  SUM(i.valor) as total
FROM zonas_geograficas z
LEFT JOIN indicadores_adicciones i ON z.id = i.zona_id
WHERE z.tipo = 'region_sanitaria'
GROUP BY z.nombre, i.tipo_indicador
ORDER BY z.nombre, i.tipo_indicador;
```

### Cruzar datos censales con indicadores

```sql
-- Tasa de indicadores por cada 10,000 habitantes
SELECT 
  z.nombre as provincia,
  dc.poblacion_total,
  COUNT(i.id) as total_indicadores,
  SUM(i.valor) as suma_valores,
  ROUND((SUM(i.valor) / dc.poblacion_total * 10000)::numeric, 2) as tasa_por_10000
FROM zonas_geograficas z
JOIN datos_censo dc ON z.id = dc.zona_id
LEFT JOIN indicadores_adicciones i ON z.id = i.zona_id
WHERE z.tipo = 'provincia'
  AND dc.anio = (SELECT MAX(anio) FROM datos_censo)
GROUP BY z.nombre, dc.poblacion_total
ORDER BY tasa_por_10000 DESC NULLS LAST;
```

### Análisis temporal de indicadores

```sql
-- Evolución mensual de indicadores por tipo
SELECT 
  DATE_TRUNC('month', fecha) as mes,
  tipo_indicador,
  COUNT(*) as cantidad,
  SUM(valor) as total,
  AVG(valor) as promedio
FROM indicadores_adicciones
GROUP BY DATE_TRUNC('month', fecha), tipo_indicador
ORDER BY mes, tipo_indicador;
```

### Identificar localidades críticas en Córdoba

```sql
-- Top 10 localidades con más indicadores de consumo
SELECT 
  l.nombre as localidad,
  l.departamento,
  l.poblacion,
  COUNT(i.id) as cantidad_indicadores,
  SUM(i.valor) as valor_total,
  ROUND((SUM(i.valor) / NULLIF(l.poblacion, 0) * 10000)::numeric, 2) as tasa_por_10000,
  MAX(i.fecha) as ultimo_registro
FROM localidades l
JOIN indicadores_adicciones i ON l.id = i.localidad_id
WHERE i.tipo_indicador = 'consumo'
GROUP BY l.id, l.nombre, l.departamento, l.poblacion
ORDER BY tasa_por_10000 DESC NULLS LAST
LIMIT 10;
```

### Análisis de proximidad a centros de atención

```sql
-- Indicadores sin centro de atención cercano (>20km)
SELECT 
  i.id,
  z.nombre as zona,
  i.tipo_indicador,
  i.valor,
  i.fecha,
  (SELECT MIN(ST_Distance(i.ubicacion::geography, c.ubicacion::geography))
   FROM centros_atencion c WHERE c.activo = true) / 1000 as distancia_centro_mas_cercano_km
FROM indicadores_adicciones i
JOIN zonas_geograficas z ON i.zona_id = z.id
WHERE i.ubicacion IS NOT NULL
HAVING (SELECT MIN(ST_Distance(i.ubicacion::geography, c.ubicacion::geography))
        FROM centros_atencion c WHERE c.activo = true) > 20000
ORDER BY distancia_centro_mas_cercano_km DESC;
```

### Exportar resultados para visualización

```sql
-- Generar GeoJSON de departamentos de Córdoba con estadísticas
SELECT json_build_object(
  'type', 'FeatureCollection',
  'features', json_agg(
    json_build_object(
      'type', 'Feature',
      'geometry', ST_AsGeoJSON(z.geom)::json,
      'properties', json_build_object(
        'nombre', z.nombre,
        'codigo', z.codigo,
        'indicadores_consumo', COALESCE(stats.consumo, 0),
        'indicadores_tratamiento', COALESCE(stats.tratamiento, 0),
        'indicadores_prevencion', COALESCE(stats.prevencion, 0),
        'indicadores_consulta', COALESCE(stats.consulta, 0)
      )
    )
  )
) as geojson
FROM zonas_geograficas z
LEFT JOIN (
  SELECT 
    zona_id,
    SUM(CASE WHEN tipo_indicador = 'consumo' THEN valor ELSE 0 END) as consumo,
    SUM(CASE WHEN tipo_indicador = 'tratamiento' THEN valor ELSE 0 END) as tratamiento,
    SUM(CASE WHEN tipo_indicador = 'prevencion' THEN valor ELSE 0 END) as prevencion,
    SUM(CASE WHEN tipo_indicador = 'consulta' THEN valor ELSE 0 END) as consulta
  FROM indicadores_adicciones
  GROUP BY zona_id
) stats ON z.id = stats.zona_id
WHERE z.tipo = 'departamento' AND z.codigo_padre = 'AR-X';
```

### Exportar localidades para Leafmap

```sql
-- CSV de localidades con indicadores para mapa de calor
COPY (
  SELECT 
    l.nombre as localidad,
    l.departamento,
    l.latitud,
    l.longitud,
    i.tipo_indicador,
    i.subtipo,
    i.valor,
    i.fecha,
    i.descripcion
  FROM indicadores_adicciones i
  JOIN localidades l ON i.localidad_id = l.id
  ORDER BY i.fecha DESC
) TO '/tmp/indicadores_cordoba.csv' WITH CSV HEADER;
```

---

## Consejos y Mejores Prácticas

### Optimización de consultas

1. **Usar índices espaciales**: Las tablas ya tienen índices GIST creados
2. **Limitar resultados**: Usar `LIMIT` en consultas exploratorias
3. **Filtrar por bounding box primero**: Usar `ST_Intersects` con un rectángulo antes de análisis detallados

### Manejo de grandes volúmenes de datos

```sql
-- Crear tabla materializada para dashboards
CREATE MATERIALIZED VIEW mv_resumen_provincial AS
SELECT 
  z.id, z.codigo, z.nombre, z.geom,
  COUNT(i.id) as total_indicadores,
  SUM(i.valor) as suma_valores
FROM zonas_geograficas z
LEFT JOIN indicadores_adicciones i ON z.id = i.zona_id
WHERE z.tipo = 'provincia'
GROUP BY z.id;

-- Actualizar periódicamente
REFRESH MATERIALIZED VIEW mv_resumen_provincial;
```

### Automatización de reportes

```bash
#!/bin/bash
# Script para generar reporte diario
docker exec gis_postgis psql -U gisuser -d gis_adicciones -c "
  SELECT tipo_indicador, COUNT(*), SUM(valor)
  FROM indicadores_adicciones
  WHERE fecha = CURRENT_DATE - 1
  GROUP BY tipo_indicador;
" > reporte_$(date +%Y%m%d).txt
```

---

## Recursos Adicionales

### Documentación Técnica

- [Documentación de PostGIS](https://postgis.net/documentation/)
- [Documentación de GeoServer](https://docs.geoserver.org/)
- [Documentación de Leafmap](https://leafmap.org/)
- [Tutorial de SQL espacial](https://postgis.net/workshops/postgis-intro/)

### Fuentes de Datos de Córdoba

Consultar el archivo [FUENTES_DATOS.md](FUENTES_DATOS.md) para:

- IDECOR - Infraestructura de Datos Espaciales de Córdoba
- Estadística Córdoba - Portal de datos estadísticos
- OpenDataCordoba - Datos abiertos colaborativos
- Mapas Córdoba - Regiones sanitarias y efectores de salud
- IGN Argentina - Capas SIG nacionales

### Soporte

Para problemas o consultas:

1. Revisar la [Guía de Instalación](SETUP.md) para solución de problemas comunes
2. Consultar los logs: `docker-compose logs -f`
3. Abrir un issue en el repositorio de GitHub
