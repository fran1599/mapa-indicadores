# Guía de Uso del Sistema

Esta guía explica cómo utilizar el sistema de visualización de indicadores de adicciones para cargar datos, crear visualizaciones y ejecutar análisis espaciales.

## Índice

1. [Acceso a los Servicios](#acceso-a-los-servicios)
2. [Cargar Datos Geográficos](#cargar-datos-geográficos)
3. [Crear Mapas de Calor en Kepler.gl](#crear-mapas-de-calor-en-keplergl)
4. [Publicar Capas en GeoServer](#publicar-capas-en-geoserver)
5. [Consultas Espaciales en PostGIS](#consultas-espaciales-en-postgis)
6. [Ejemplos de Análisis](#ejemplos-de-análisis)

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

### Kepler.gl (Visualización)

1. Abrir http://localhost:8081
2. No requiere autenticación

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

## Crear Mapas de Calor en Kepler.gl

### Paso 1: Exportar datos desde PostGIS

```sql
-- Exportar indicadores con coordenadas para Kepler.gl
COPY (
  SELECT 
    i.id,
    z.nombre as zona,
    i.tipo_indicador,
    i.valor,
    i.fecha,
    ST_X(i.ubicacion) as longitud,
    ST_Y(i.ubicacion) as latitud
  FROM indicadores_adicciones i
  JOIN zonas_geograficas z ON i.zona_id = z.id
  WHERE i.ubicacion IS NOT NULL
) TO '/tmp/indicadores_kepler.csv' WITH CSV HEADER;
```

O desde terminal:
```bash
docker exec gis_postgis psql -U gisuser -d gis_adicciones -c "
COPY (
  SELECT 
    i.id,
    z.nombre as zona,
    i.tipo_indicador,
    i.valor,
    i.fecha,
    ST_X(i.ubicacion) as longitud,
    ST_Y(i.ubicacion) as latitud
  FROM indicadores_adicciones i
  JOIN zonas_geograficas z ON i.zona_id = z.id
  WHERE i.ubicacion IS NOT NULL
) TO STDOUT WITH CSV HEADER;" > indicadores_kepler.csv
```

### Paso 2: Cargar en Kepler.gl

1. Abrir http://localhost:8081
2. Arrastrar el archivo CSV a la interfaz
3. Kepler.gl detectará automáticamente las columnas de latitud/longitud

### Paso 3: Configurar mapa de calor

1. En el panel izquierdo, clic en la capa de datos
2. Cambiar "Layer Type" a "Heatmap"
3. Configurar:
   - **Weight**: Seleccionar columna `valor`
   - **Radius**: Ajustar según densidad de datos
   - **Intensity**: Ajustar escala de colores

### Paso 4: Filtrar datos

1. Agregar filtro por `tipo_indicador`:
   - Clic en "Add Filter"
   - Seleccionar columna `tipo_indicador`
   - Elegir valores a mostrar

2. Agregar filtro temporal por `fecha`:
   - Clic en "Add Filter"
   - Seleccionar columna `fecha`
   - Usar slider para rango de fechas

### Paso 5: Exportar visualización

1. Clic en "Share" (esquina superior derecha)
2. Opciones:
   - **Export Image**: PNG/JPG de la vista actual
   - **Export Data**: Datos procesados
   - **Export Map**: Configuración completa del mapa

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

## Ejemplos de Análisis

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

### Identificar zonas críticas

```sql
-- Top 10 zonas con más indicadores de consumo
SELECT 
  z.nombre,
  z.tipo,
  COUNT(i.id) as cantidad_indicadores,
  SUM(i.valor) as valor_total,
  MAX(i.fecha) as ultimo_registro
FROM zonas_geograficas z
JOIN indicadores_adicciones i ON z.id = i.zona_id
WHERE i.tipo_indicador = 'consumo'
GROUP BY z.id, z.nombre, z.tipo
ORDER BY valor_total DESC
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
-- Generar GeoJSON de zonas con estadísticas
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
        'indicadores_prevencion', COALESCE(stats.prevencion, 0)
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
    SUM(CASE WHEN tipo_indicador = 'prevencion' THEN valor ELSE 0 END) as prevencion
  FROM indicadores_adicciones
  GROUP BY zona_id
) stats ON z.id = stats.zona_id
WHERE z.tipo = 'provincia';
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

- [Documentación de PostGIS](https://postgis.net/documentation/)
- [Documentación de GeoServer](https://docs.geoserver.org/)
- [Documentación de Kepler.gl](https://docs.kepler.gl/)
- [Tutorial de SQL espacial](https://postgis.net/workshops/postgis-intro/)
