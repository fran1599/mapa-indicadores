# Sistema de Visualización de Indicadores de Adicciones

Sistema dockerizado para visualizar indicadores de la secretaría de adicciones en mapas geográficos, con capacidad de definir zonas geográficas, generar mapas de calor y cruzar datos censales con datos de consumo/tratamiento.

## 🎯 Características

- **PostGIS**: Base de datos geoespacial para almacenar zonas, indicadores y datos censales
- **GeoServer**: Servidor de mapas para publicar capas WMS/WFS
- **Kepler.gl**: Visualización interactiva de mapas de calor
- **pgAdmin**: Interfaz web para administrar la base de datos

## 📋 Requisitos Previos

- [Docker](https://docs.docker.com/get-docker/) (versión 20.10 o superior)
- [Docker Compose](https://docs.docker.com/compose/install/) (versión 2.0 o superior)
- 4 GB de RAM mínimo disponible
- 10 GB de espacio en disco

## 🚀 Instalación Rápida

```bash
# 1. Clonar el repositorio
git clone https://github.com/tu-usuario/mapa-indicadores.git
cd mapa-indicadores

# 2. Copiar archivo de configuración
cp .env.example .env

# 3. Iniciar los servicios
docker-compose up -d

# 4. Verificar que los servicios estén corriendo
docker-compose ps

# 5. Cargar datos de ejemplo (opcional)
./scripts/load-sample-data.sh
```

## 🌐 URLs de Acceso

| Servicio | URL | Descripción |
|----------|-----|-------------|
| pgAdmin | http://localhost:5050 | Administración de PostgreSQL |
| GeoServer | http://localhost:8080/geoserver | Servidor de mapas |
| Kepler.gl | http://localhost:8081 | Visualización de mapas de calor |
| PostgreSQL | localhost:5432 | Base de datos (conexión directa) |

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
├── docker-compose.yml      # Configuración de servicios Docker
├── README.md               # Este archivo
├── .env.example            # Plantilla de variables de entorno
├── .gitignore              # Archivos ignorados por Git
├── data/
│   ├── provincias_argentina.geojson  # Geometrías de provincias
│   └── datos_ejemplo.csv             # Datos de ejemplo
├── scripts/
│   ├── init-db.sql         # Esquema inicial de la base de datos
│   └── load-sample-data.sh # Script para cargar datos de ejemplo
└── docs/
    ├── SETUP.md            # Guía detallada de instalación
    └── USO.md              # Guía de uso del sistema
```

## 🗄️ Estructura de la Base de Datos

### Tablas Principales

- **zonas_geograficas**: Provincias, departamentos y localidades con geometrías
- **datos_censo**: Información censal por zona y año
- **indicadores_adicciones**: Indicadores de consumo, tratamiento y prevención
- **centros_atencion**: Ubicación de centros de atención

### Funciones Disponibles

- `encontrar_zona(punto)`: Encuentra la zona geográfica de un punto
- `estadisticas_zona(zona_id, fecha_inicio, fecha_fin)`: Estadísticas por zona
- `indicadores_cercanos(punto, radio, limite)`: Indicadores cerca de un punto

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

# Ejecutar consulta SQL
docker exec -it gis_postgis psql -U gisuser -d gis_adicciones -c "SELECT * FROM zonas_geograficas;"
```

## 📖 Documentación Adicional

- [Guía de Instalación Detallada](docs/SETUP.md)
- [Guía de Uso](docs/USO.md)

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
