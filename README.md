# Sistema de Visualización de Indicadores de Adicciones - Córdoba

Sistema dockerizado para visualizar indicadores de la secretaría de adicciones en mapas geográficos de la Provincia de Córdoba, Argentina. Permite definir zonas geográficas, generar mapas de calor y cruzar datos censales con datos de consumo/tratamiento.

## 🎯 Características

- **PostGIS**: Base de datos geoespacial para almacenar zonas, indicadores y datos censales
- **GeoServer**: Servidor de mapas para publicar capas WMS/WFS
- **Kepler.gl**: Visualización interactiva de mapas de calor (opcional, requiere Mapbox)
- **MapStore**: Alternativa a Kepler.gl sin necesidad de API key externas
- **Webapp Leaflet**: Aplicación web simple con OpenStreetMap (recomendado, sin API keys)
- **pgAdmin**: Interfaz web para administrar la base de datos
- **Datos de Córdoba**: 26 departamentos, 14 regiones sanitarias y más de 50 localidades precargadas
- **Geocodificación**: Script Python para geocodificar localidades de Córdoba
- **100% Libre de API Keys**: Sistema funcional sin registros en servicios externos

## 📋 Requisitos Previos

- [Docker](https://docs.docker.com/get-docker/) (versión 20.10 o superior)
- [Docker Compose](https://docs.docker.com/compose/install/) (versión 2.0 o superior)
- 4 GB de RAM mínimo disponible
- 10 GB de espacio en disco

## 🚀 Instalación Rápida

```bash
# 1. Clonar el repositorio
git clone https://github.com/fran1599/mapa-indicadores.git
cd mapa-indicadores

# 2. Copiar archivo de configuración
cp .env.example .env

# 3. Iniciar los servicios
docker-compose up -d

# 4. Verificar que los servicios estén corriendo
docker-compose ps

# 5. Cargar datos de Córdoba
chmod +x scripts/cargar_datos.sh
./scripts/cargar_datos.sh
```

## 🌐 URLs de Acceso

| Servicio | URL | Descripción |
|----------|-----|-------------|
| pgAdmin | http://localhost:5050 | Administración de PostgreSQL |
| GeoServer | http://localhost:8080/geoserver | Servidor de mapas |
| Kepler.gl | http://localhost:8081 | Visualización (requiere Mapbox, opcional) |
| MapStore | http://localhost:8082 | Visualización de mapas (sin Mapbox) |
| Webapp Leaflet | http://localhost:8083 | Webapp con OpenStreetMap (recomendado) |
| PostgreSQL | localhost:5432 | Base de datos (conexión directa) |

> 💡 **Recomendado**: Para empezar sin configuración adicional, usá la Webapp Leaflet en http://localhost:8083

## 🔐 Credenciales por Defecto

### pgAdmin
- **Email**: admin@local.dev
- **Contraseña**: admin123

### GeoServer
- **Usuario**: admin
- **Contraseña**: admin123

### PostgreSQL
- **Base de datos**: gis_adicciones
- **Usuario**: gisuser
- **Contraseña**: gispassword

> ⚠️ **Importante**: Cambia estas credenciales en producción editando el archivo `.env`

## 📁 Estructura del Proyecto

```
├── docker-compose.yml          # Configuración de servicios Docker
├── README.md                   # Este archivo
├── .env.example                # Plantilla de variables de entorno
├── .gitignore                  # Archivos ignorados por Git
│
├── config/
│   ├── map-style-osm.json            # Estilo OpenStreetMap (gratuito)
│   ├── map-style-carto-light.json    # Estilo Carto claro (gratuito)
│   └── map-style-carto-dark.json     # Estilo Carto oscuro (gratuito)
│
├── data/
│   ├── cordoba/
│   │   ├── departamentos.geojson     # 26 departamentos de Córdoba
│   │   ├── localidades.csv           # Localidades con coordenadas
│   │   └── regiones_sanitarias.geojson  # 14 regiones sanitarias
│   ├── provincias_argentina.geojson  # Geometrías de provincias
│   └── ejemplo_indicadores.csv       # Datos de ejemplo
│
├── webapp/
│   ├── index.html              # Aplicación web con Leaflet
│   └── app.js                  # Lógica de la aplicación
│
├── scripts/
│   ├── init-db.sql             # Esquema inicial de la base de datos
│   ├── geocodificar.py         # Script de geocodificación
│   ├── cargar_datos.sh         # Cargar datos de Córdoba
│   └── load-sample-data.sh     # Cargar datos de ejemplo general
│
└── docs/
    ├── SETUP.md                # Guía detallada de instalación
    ├── USO.md                  # Guía de uso del sistema
    └── FUENTES_DATOS.md        # Enlaces a fuentes oficiales
```

## 🗄️ Estructura de la Base de Datos

### Tablas Principales

- **zonas_geograficas**: Provincias, departamentos, regiones sanitarias y barrios con geometrías
- **localidades**: Localidades con coordenadas puntuales (lat/lon)
- **datos_censo**: Información censal por zona y año
- **indicadores_adicciones**: Indicadores de consumo, tratamiento, prevención y consultas
- **centros_atencion**: Ubicación de centros de atención (hospitales, CPA, comunidades terapéuticas)

### Funciones Disponibles

- `encontrar_zona(punto)`: Encuentra la zona geográfica de un punto
- `estadisticas_zona(zona_id, fecha_inicio, fecha_fin)`: Estadísticas por zona
- `indicadores_cercanos(punto, radio, limite)`: Indicadores cerca de un punto

## 🗺️ Datos de Córdoba Incluidos

### Departamentos (26)
Capital, Río Cuarto, San Justo, Punilla, Colón, General San Martín, Tercero Arriba, Río Segundo, Marcos Juárez, Unión, General Roca, Juárez Celman, Presidente Roque Sáenz Peña, Santa María, Cruz del Eje, San Alberto, Calamuchita, Río Primero, Totoral, Ischilín, Tulumba, Sobremonte, Río Seco, Pocho, Minas, San Javier

### Regiones Sanitarias (14)
Capital, Punilla, Colón, Norte, Cruz del Eje, Traslasierra, Santa María, Río Segundo, Tercero Arriba, San Justo, Unión, General San Martín, Río Cuarto, Sur

### Localidades (55+)
Córdoba, Río Cuarto, Villa María, San Francisco, Carlos Paz, Alta Gracia, Río Tercero, Jesús María, Bell Ville, Cruz del Eje, y más...

## 📍 Geocodificación

El script `geocodificar.py` permite agregar coordenadas a archivos CSV con localidades de Córdoba:

```bash
# Geocodificar archivo CSV
python scripts/geocodificar.py --input datos.csv --columna localidad --output datos_geo.csv

# Ver localidades disponibles
python scripts/geocodificar.py --listar-localidades

# Usar solo base de datos local (sin consultas a Internet)
python scripts/geocodificar.py --input datos.csv --columna ciudad --output datos_geo.csv --solo-local
```

## 🔧 Comandos Útiles

```bash
# Ver logs de los servicios
docker-compose logs -f

# Detener servicios
docker-compose down

# Reiniciar un servicio específico
docker-compose restart postgis

# Acceder a la base de datos
docker exec -it gis_postgis psql -U gisuser -d gis_adicciones

# Consultar departamentos de Córdoba
docker exec -it gis_postgis psql -U gisuser -d gis_adicciones -c \
  "SELECT nombre, tipo FROM zonas_geograficas WHERE tipo = 'departamento';"

# Consultar localidades
docker exec -it gis_postgis psql -U gisuser -d gis_adicciones -c \
  "SELECT nombre, departamento, poblacion FROM localidades ORDER BY poblacion DESC LIMIT 10;"
```

## 🔥 Crear Mapa de Calor

### Opción 1: Webapp Leaflet (Recomendado - Sin API key)

1. Acceder a http://localhost:8083
2. El mapa de calor de ejemplo se carga automáticamente
3. Usar el selector de capas para cambiar entre estilos (OpenStreetMap, Carto Claro, Carto Oscuro)
4. Hacer clic en los marcadores para ver detalles

### Opción 2: Kepler.gl (Requiere Mapbox token)

1. Exportar datos con coordenadas desde PostGIS:
   ```sql
   SELECT l.nombre, l.latitud, l.longitud, i.tipo_indicador, i.valor
   FROM indicadores_adicciones i
   JOIN localidades l ON i.localidad_id = l.id;
   ```
2. Guardar como CSV
3. Abrir http://localhost:8081
4. Arrastrar el archivo CSV
5. Cambiar tipo de capa a "Heatmap"
6. Configurar peso por columna `valor`

> ⚠️ **Nota**: Kepler.gl requiere un token de Mapbox. Si no tenés uno, usá la Webapp Leaflet en http://localhost:8083

## 📖 Documentación Adicional

- [Guía de Instalación Detallada](docs/SETUP.md)
- [Guía de Uso](docs/USO.md)
- [Fuentes de Datos Oficiales](docs/FUENTES_DATOS.md)

## 🔜 Próximos Pasos Sugeridos

1. **Cargar datos reales**: Reemplazar los datos de ejemplo con datos reales de la secretaría
2. **Configurar GeoServer**: Publicar las capas de zonas e indicadores
3. **Personalizar Kepler.gl**: Crear dashboards específicos para análisis
4. **Agregar autenticación**: Implementar control de acceso a los servicios
5. **Configurar backups**: Establecer respaldos automáticos de la base de datos
6. **Escalar servicios**: Agregar réplicas según demanda

## 🤝 Contribuir

Las contribuciones son bienvenidas. Por favor, lee las guías de contribución antes de enviar un pull request.

## 📄 Licencia

Este proyecto está bajo la Licencia GPL-3.0. Ver el archivo [LICENSE](LICENSE) para más detalles.
