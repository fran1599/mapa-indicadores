#!/bin/bash

# Script para cargar datos de ejemplo en la base de datos PostGIS
# Uso: ./load-sample-data.sh

set -e

# Configuración
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${POSTGRES_DB:-gis_adicciones}"
DB_USER="${POSTGRES_USER:-gisuser}"
DB_PASS="${POSTGRES_PASSWORD:-gispassword}"

# Colores para mensajes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # Sin color

echo -e "${YELLOW}=== Cargador de Datos de Ejemplo ===${NC}"
echo ""

# Función para esperar a que PostGIS esté listo
wait_for_postgis() {
    echo -e "${YELLOW}Esperando a que PostGIS esté disponible...${NC}"
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
            echo -e "${GREEN}PostGIS está listo!${NC}"
            return 0
        fi
        echo "Intento $attempt de $max_attempts..."
        sleep 2
        ((attempt++))
    done
    
    echo -e "${RED}Error: No se pudo conectar a PostGIS después de $max_attempts intentos${NC}"
    return 1
}

# Función para cargar GeoJSON de provincias
load_geojson() {
    echo -e "${YELLOW}Cargando GeoJSON de provincias...${NC}"
    
    # Obtener ruta absoluta del directorio del script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local geojson_file="${script_dir}/../data/provincias_argentina.geojson"
    
    if [ ! -f "$geojson_file" ]; then
        echo -e "${RED}Error: No se encontró el archivo $geojson_file${NC}"
        return 1
    fi
    
    # Obtener ruta absoluta
    geojson_file="$(cd "$(dirname "$geojson_file")" && pwd)/$(basename "$geojson_file")"
    
    # Usar ogr2ogr si está disponible, sino usar SQL directo
    if command -v ogr2ogr &> /dev/null; then
        PGPASSWORD="$DB_PASS" ogr2ogr -f "PostgreSQL" \
            "PG:host=$DB_HOST port=$DB_PORT dbname=$DB_NAME user=$DB_USER password=$DB_PASS" \
            "$geojson_file" \
            -nln zonas_geograficas_temp \
            -overwrite
        
        # Migrar datos a la tabla principal
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOF
INSERT INTO zonas_geograficas (codigo, nombre, tipo, geom)
SELECT 
    COALESCE(codigo, 'AR-' || id::text),
    nombre,
    'provincia',
    ST_Multi(ST_Transform(wkb_geometry, 4326))
FROM zonas_geograficas_temp
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    geom = EXCLUDED.geom,
    updated_at = CURRENT_TIMESTAMP;

DROP TABLE IF EXISTS zonas_geograficas_temp;
EOF
    else
        echo -e "${YELLOW}ogr2ogr no disponible, cargando datos con SQL...${NC}"
        # Cargar provincias directamente con SQL (datos simplificados)
        PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<'EOF'
-- Insertar provincias con geometrías simplificadas (centroides como polígonos pequeños)
INSERT INTO zonas_geograficas (codigo, nombre, tipo, geom) VALUES
('AR-C', 'Ciudad Autónoma de Buenos Aires', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-58.3816, -34.6037), 4326)::geography, 10000)::geometry)),
('AR-B', 'Buenos Aires', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-59.0, -36.0), 4326)::geography, 100000)::geometry)),
('AR-K', 'Catamarca', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-65.7796, -28.4696), 4326)::geography, 80000)::geometry)),
('AR-H', 'Chaco', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-60.4409, -27.4259), 4326)::geography, 80000)::geometry)),
('AR-U', 'Chubut', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-68.5, -43.5), 4326)::geography, 100000)::geometry)),
('AR-X', 'Córdoba', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-64.1888, -31.4201), 4326)::geography, 80000)::geometry)),
('AR-W', 'Corrientes', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-58.8341, -27.4692), 4326)::geography, 70000)::geometry)),
('AR-E', 'Entre Ríos', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-59.6, -31.7), 4326)::geography, 70000)::geometry)),
('AR-P', 'Formosa', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-59.4515, -24.8940), 4326)::geography, 70000)::geometry)),
('AR-Y', 'Jujuy', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-65.3, -23.3), 4326)::geography, 50000)::geometry)),
('AR-L', 'La Pampa', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-65.5, -37.0), 4326)::geography, 80000)::geometry)),
('AR-F', 'La Rioja', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-66.8500, -29.4131), 4326)::geography, 70000)::geometry)),
('AR-M', 'Mendoza', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-68.8458, -32.8908), 4326)::geography, 80000)::geometry)),
('AR-N', 'Misiones', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-55.8967, -27.3621), 4326)::geography, 50000)::geometry)),
('AR-Q', 'Neuquén', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-70.0, -38.5), 4326)::geography, 70000)::geometry)),
('AR-R', 'Río Negro', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-67.0, -40.0), 4326)::geography, 90000)::geometry)),
('AR-A', 'Salta', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-65.4117, -24.7821), 4326)::geography, 80000)::geometry)),
('AR-J', 'San Juan', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-68.5364, -31.5375), 4326)::geography, 70000)::geometry)),
('AR-D', 'San Luis', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-66.3356, -33.2962), 4326)::geography, 70000)::geometry)),
('AR-Z', 'Santa Cruz', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-69.0, -49.0), 4326)::geography, 100000)::geometry)),
('AR-S', 'Santa Fe', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-60.7, -31.6), 4326)::geography, 80000)::geometry)),
('AR-G', 'Santiago del Estero', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-64.2615, -27.7834), 4326)::geography, 80000)::geometry)),
('AR-V', 'Tierra del Fuego', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-68.3, -54.3), 4326)::geography, 50000)::geometry)),
('AR-T', 'Tucumán', 'provincia', ST_Multi(ST_Buffer(ST_SetSRID(ST_MakePoint(-65.2226, -26.8241), 4326)::geography, 40000)::geometry))
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    geom = EXCLUDED.geom,
    updated_at = CURRENT_TIMESTAMP;
EOF
    fi
    
    echo -e "${GREEN}Provincias cargadas correctamente${NC}"
}

# Función para cargar datos de ejemplo del CSV
load_csv_data() {
    echo -e "${YELLOW}Cargando datos de ejemplo del CSV...${NC}"
    
    # Obtener ruta absoluta del directorio del script
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local csv_file="${script_dir}/../data/datos_ejemplo.csv"
    
    # Verificar que el archivo existe
    if [ ! -f "$csv_file" ]; then
        echo -e "${RED}Error: No se encontró el archivo $csv_file${NC}"
        return 1
    fi
    
    # Obtener ruta absoluta del CSV
    csv_file="$(cd "$(dirname "$csv_file")" && pwd)/$(basename "$csv_file")"
    
    # Crear tabla temporal y cargar CSV usando \copy con ruta absoluta
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Crear tabla temporal para importar CSV
CREATE TEMP TABLE datos_temp (
    zona_codigo VARCHAR(20),
    fecha DATE,
    tipo_indicador VARCHAR(30),
    valor NUMERIC(12, 2),
    descripcion TEXT
);
EOSQL

    # Usar \copy en un comando separado para permitir la expansión de variables
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "\\copy datos_temp FROM '$csv_file' WITH (FORMAT csv, HEADER true, DELIMITER ',')"
    
    # Insertar datos y mostrar resumen
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Insertar datos en la tabla de indicadores
INSERT INTO indicadores_adicciones (zona_id, fecha, tipo_indicador, valor, descripcion)
SELECT 
    z.id,
    d.fecha,
    d.tipo_indicador,
    d.valor,
    d.descripcion
FROM datos_temp d
JOIN zonas_geograficas z ON z.codigo = d.zona_codigo;

-- Mostrar resumen
SELECT tipo_indicador, COUNT(*) as cantidad 
FROM indicadores_adicciones 
GROUP BY tipo_indicador;
EOSQL
    
    echo -e "${GREEN}Datos de ejemplo cargados correctamente${NC}"
}

# Función principal
main() {
    echo "Configuración:"
    echo "  - Host: $DB_HOST"
    echo "  - Puerto: $DB_PORT"
    echo "  - Base de datos: $DB_NAME"
    echo "  - Usuario: $DB_USER"
    echo ""
    
    # Esperar a que PostGIS esté listo
    wait_for_postgis || exit 1
    
    # Cargar datos
    load_geojson
    load_csv_data
    
    echo ""
    echo -e "${GREEN}=== Carga de datos completada exitosamente ===${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "  1. Acceder a pgAdmin en http://localhost:5050"
    echo "  2. Verificar los datos en las tablas"
    echo "  3. Configurar GeoServer para publicar las capas"
}

# Ejecutar
main "$@"
