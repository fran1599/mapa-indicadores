# Fuentes de Datos Oficiales

Este documento lista las fuentes oficiales de datos geográficos y estadísticos de la Provincia de Córdoba, Argentina, que pueden ser utilizados para enriquecer el sistema de indicadores de adicciones.

## 📊 Datos Geográficos

### IDECOR - Infraestructura de Datos Espaciales de Córdoba

**URL**: https://www.idecor.gob.ar/descargas/

IDECOR es la principal fuente de datos geográficos oficiales de la provincia. Ofrece:

- **Límites administrativos**: Departamentos, pedanías, localidades
- **Infraestructura**: Rutas, caminos, ferrocarriles
- **Hidrografía**: Ríos, arroyos, embalses
- **Catastro**: Parcelas urbanas y rurales
- **Imágenes satelitales**: Coberturas recientes

Formatos disponibles: Shapefile, GeoJSON, GeoPackage, WMS/WFS

### Estadística Córdoba - Geodatos

**URL**: https://estadistica.cba.gov.ar/geodata/

Portal de datos estadísticos y geográficos de la Dirección General de Estadística y Censos:

- Datos censales georreferenciados
- Indicadores socioeconómicos por departamento
- Series históricas de población
- Mapas temáticos

### OpenDataCordoba - Mapas de Córdoba

**URL**: https://github.com/OpenDataCordoba/mapas-de-cordoba

Repositorio colaborativo con datos geográficos abiertos:

- GeoJSON de departamentos
- Límites de barrios de la ciudad de Córdoba
- Datos de transporte público
- Información de espacios públicos

Licencia: Creative Commons (CC-BY)

### Mapas Córdoba - Regiones Sanitarias

**URL**: https://mapascordoba.gob.ar/viewer/mapa/301

Visualizador oficial del gobierno provincial con las regiones sanitarias:

- 14 regiones sanitarias de la provincia
- Jurisdicciones de centros de salud
- Ubicación de hospitales y centros de atención primaria

### IGN Argentina - Capas SIG

**URL**: https://www.ign.gob.ar/NuestrasActividades/InformacionGeoespacial/CapasSIG

Instituto Geográfico Nacional - Datos de todo el país:

- Límites provinciales y departamentales oficiales
- Red vial nacional y provincial
- Toponimia oficial
- Modelo digital de elevación

Formato: Shapefile, GeoJSON, servicios WMS/WFS

## 🏥 Datos de Salud

### Ministerio de Salud de Córdoba

**URL**: https://www.cba.gov.ar/salud/

- Listado de efectores de salud
- Estadísticas sanitarias provinciales
- Programas de prevención y tratamiento

### SEDRONAR - Observatorio Argentino de Drogas

**URL**: https://www.argentina.gob.ar/sedronar

Datos nacionales sobre consumo de sustancias:

- Encuestas nacionales de consumo
- Estadísticas de tratamiento
- Indicadores epidemiológicos

## 📈 Datos Estadísticos

### INDEC - Censos Nacionales

**URL**: https://www.indec.gob.ar/

Instituto Nacional de Estadística y Censos:

- Censo Nacional de Población 2022
- Datos demográficos por departamento
- Encuesta Permanente de Hogares

### Dirección General de Estadística y Censos de Córdoba

**URL**: https://estadistica.cba.gov.ar/

- Anuario estadístico provincial
- Proyecciones de población
- Indicadores socioeconómicos

## 🗺️ Servicios de Mapas (WMS/WFS)

### GeoServicios IDECOR

```
WMS: https://www.mapascordoba.gob.ar/geoserver/wms
WFS: https://www.mapascordoba.gob.ar/geoserver/wfs
```

Capas disponibles:
- `limite_departamental`
- `localidades`
- `rutas_provinciales`
- `hidrografia`

### GeoServicios IGN

```
WMS: https://wms.ign.gob.ar/geoserver/wms
WFS: https://wms.ign.gob.ar/geoserver/wfs
```

## 📥 Cómo Utilizar los Datos

### Descargar GeoJSON de IDECOR

1. Ir a https://www.idecor.gob.ar/descargas/
2. Seleccionar la capa deseada (ej: "Departamentos")
3. Elegir formato "GeoJSON"
4. Descargar y guardar en `data/cordoba/`

### Conectar WMS en GeoServer

1. En GeoServer, ir a "Stores" → "Add new Store"
2. Seleccionar "WMS" 
3. Configurar URL del servicio WMS
4. Publicar las capas deseadas

### Importar Shapefile en PostGIS

```bash
# Usando shp2pgsql
shp2pgsql -s 4326 -I archivo.shp nombre_tabla | \
  psql -h localhost -U gisuser -d gis_adicciones

# Usando ogr2ogr
ogr2ogr -f "PostgreSQL" \
  "PG:host=localhost dbname=gis_adicciones user=gisuser password=gispassword" \
  archivo.shp \
  -nln nombre_tabla \
  -s_srs EPSG:4326
```

## ⚠️ Consideraciones Legales

### Licencias de Datos

- **IDECOR**: Licencia de datos abiertos del Estado Provincial
- **IGN**: Datos públicos con atribución requerida
- **OpenDataCordoba**: Creative Commons CC-BY
- **INDEC**: Datos públicos de uso libre

### Atribución Requerida

Al utilizar estos datos, incluir atribución en la forma:

> Datos geográficos: IDECOR - Gobierno de Córdoba
> Datos censales: INDEC - Censo Nacional 2022
> Límites administrativos: IGN - Instituto Geográfico Nacional

### Uso Responsable

- No redistribuir datos con modificaciones sin autorización
- Citar la fuente original en publicaciones
- Verificar la licencia específica de cada conjunto de datos
- Mantener actualizados los datos cuando sea posible

## 🔄 Actualizaciones

Los datos oficiales se actualizan periódicamente:

| Fuente | Frecuencia de Actualización |
|--------|----------------------------|
| IDECOR | Continua |
| Censos INDEC | Cada 10 años |
| Estadísticas provinciales | Anual |
| Regiones sanitarias | Según cambios administrativos |

Se recomienda verificar las fuentes periódicamente para obtener las versiones más recientes de los datos.

## 📞 Contacto

Para solicitar datos específicos o reportar errores:

- **IDECOR**: idecor@cba.gov.ar
- **Estadística Córdoba**: estadistica@cba.gov.ar
- **IGN**: consultas@ign.gob.ar
