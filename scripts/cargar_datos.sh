#!/bin/bash
# =============================================================================
# Script para cargar datos iniciales de Córdoba en la base de datos PostGIS
# =============================================================================
#
# Este script carga:
# - Departamentos de Córdoba (GeoJSON)
# - Localidades de Córdoba (CSV)
# - Regiones Sanitarias (GeoJSON)
# - Datos de ejemplo de indicadores (CSV)
#
# Uso: ./cargar_datos.sh
#
# Requisitos:
# - Docker y Docker Compose instalados
# - Contenedor gis_postgis corriendo
#
# =============================================================================

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
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/../data"
CORDOBA_DIR="${DATA_DIR}/cordoba"

# =============================================================================
# Funciones
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

print_step() {
    echo -e "${YELLOW}▸ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Función para esperar a que PostGIS esté listo
wait_for_postgis() {
    print_step "Esperando a que PostGIS esté disponible..."
    local max_attempts=30
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
            print_success "PostGIS está listo"
            return 0
        fi
        echo "  Intento $attempt de $max_attempts..."
        sleep 2
        ((attempt++))
    done
    
    print_error "No se pudo conectar a PostGIS después de $max_attempts intentos"
    return 1
}

# Función para cargar departamentos desde GeoJSON
cargar_departamentos() {
    print_step "Cargando departamentos de Córdoba..."
    
    local geojson_file="${CORDOBA_DIR}/departamentos.geojson"
    
    if [ ! -f "$geojson_file" ]; then
        print_error "No se encontró el archivo $geojson_file"
        return 1
    fi
    
    # Validar que el archivo está en el directorio esperado
    local real_path
    real_path=$(realpath "$geojson_file")
    local expected_dir
    expected_dir=$(realpath "$CORDOBA_DIR")
    
    if [[ ! "$real_path" =~ ^"$expected_dir" ]]; then
        print_error "El archivo no está en el directorio esperado: $CORDOBA_DIR"
        return 1
    fi
    
    # Leer el contenido del GeoJSON
    local geojson_content
    geojson_content=$(cat "$geojson_file")
    
    # Insertar departamentos usando SQL
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Insertar provincia de Córdoba primero
INSERT INTO zonas_geograficas (codigo, nombre, tipo, geom)
VALUES (
    'AR-X',
    'Córdoba',
    'provincia',
    ST_Multi(ST_GeomFromGeoJSON('{"type":"Polygon","coordinates":[[[-65.8,-29.4],[-65.8,-35.0],[-61.7,-35.0],[-61.7,-29.4],[-65.8,-29.4]]]}'))
)
ON CONFLICT (codigo) DO UPDATE SET
    nombre = EXCLUDED.nombre,
    geom = EXCLUDED.geom,
    updated_at = CURRENT_TIMESTAMP;

-- Insertar departamentos desde GeoJSON
DO \$\$
DECLARE
    feature JSONB;
    features JSONB;
BEGIN
    features := '${geojson_content}'::JSONB -> 'features';
    
    FOR feature IN SELECT jsonb_array_elements(features)
    LOOP
        INSERT INTO zonas_geograficas (codigo, nombre, tipo, codigo_padre, geom)
        VALUES (
            feature -> 'properties' ->> 'codigo',
            feature -> 'properties' ->> 'nombre',
            'departamento',
            'AR-X',
            ST_Multi(ST_GeomFromGeoJSON(feature -> 'geometry'))
        )
        ON CONFLICT (codigo) DO UPDATE SET
            nombre = EXCLUDED.nombre,
            geom = EXCLUDED.geom,
            updated_at = CURRENT_TIMESTAMP;
    END LOOP;
    
    RAISE NOTICE 'Departamentos cargados correctamente';
END \$\$;

-- Mostrar resumen
SELECT 'Departamentos cargados: ' || COUNT(*) FROM zonas_geograficas WHERE tipo = 'departamento';
EOSQL
    
    print_success "Departamentos cargados correctamente"
}

# Función para cargar regiones sanitarias desde GeoJSON
cargar_regiones_sanitarias() {
    print_step "Cargando regiones sanitarias..."
    
    local geojson_file="${CORDOBA_DIR}/regiones_sanitarias.geojson"
    
    if [ ! -f "$geojson_file" ]; then
        print_error "No se encontró el archivo $geojson_file"
        return 1
    fi
    
    # Validar que el archivo está en el directorio esperado
    local real_path
    real_path=$(realpath "$geojson_file")
    local expected_dir
    expected_dir=$(realpath "$CORDOBA_DIR")
    
    if [[ ! "$real_path" =~ ^"$expected_dir" ]]; then
        print_error "El archivo no está en el directorio esperado: $CORDOBA_DIR"
        return 1
    fi
    
    local geojson_content
    geojson_content=$(cat "$geojson_file")
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Insertar regiones sanitarias desde GeoJSON
DO \$\$
DECLARE
    feature JSONB;
    features JSONB;
BEGIN
    features := '${geojson_content}'::JSONB -> 'features';
    
    FOR feature IN SELECT jsonb_array_elements(features)
    LOOP
        INSERT INTO zonas_geograficas (codigo, nombre, tipo, codigo_padre, geom)
        VALUES (
            feature -> 'properties' ->> 'codigo',
            feature -> 'properties' ->> 'nombre',
            'region_sanitaria',
            'AR-X',
            ST_Multi(ST_GeomFromGeoJSON(feature -> 'geometry'))
        )
        ON CONFLICT (codigo) DO UPDATE SET
            nombre = EXCLUDED.nombre,
            geom = EXCLUDED.geom,
            updated_at = CURRENT_TIMESTAMP;
    END LOOP;
    
    RAISE NOTICE 'Regiones sanitarias cargadas correctamente';
END \$\$;

-- Mostrar resumen
SELECT 'Regiones sanitarias cargadas: ' || COUNT(*) FROM zonas_geograficas WHERE tipo = 'region_sanitaria';
EOSQL
    
    print_success "Regiones sanitarias cargadas correctamente"
}

# Función para cargar localidades desde CSV
cargar_localidades() {
    print_step "Cargando localidades..."
    
    local csv_file="${CORDOBA_DIR}/localidades.csv"
    
    if [ ! -f "$csv_file" ]; then
        print_error "No se encontró el archivo $csv_file"
        return 1
    fi
    
    # Validar que el archivo está en el directorio esperado
    local real_path
    real_path=$(realpath "$csv_file")
    local expected_dir
    expected_dir=$(realpath "$CORDOBA_DIR")
    
    if [[ ! "$real_path" =~ ^"$expected_dir" ]]; then
        print_error "El archivo no está en el directorio esperado: $CORDOBA_DIR"
        return 1
    fi
    
    # Crear tabla temporal y cargar CSV
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Crear tabla temporal para importar CSV
CREATE TEMP TABLE localidades_temp (
    codigo VARCHAR(20),
    nombre VARCHAR(200),
    departamento VARCHAR(200),
    latitud DECIMAL(10,6),
    longitud DECIMAL(10,6),
    poblacion INTEGER
);
EOSQL

    # Cargar CSV usando COPY
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "\\copy localidades_temp FROM '${csv_file}' WITH (FORMAT csv, HEADER true, DELIMITER ',')"
    
    # Insertar en tabla final
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Insertar localidades desde tabla temporal
INSERT INTO localidades (codigo, nombre, departamento, latitud, longitud, ubicacion, poblacion)
SELECT 
    codigo,
    nombre,
    departamento,
    latitud,
    longitud,
    ST_SetSRID(ST_MakePoint(longitud, latitud), 4326),
    poblacion
FROM localidades_temp
ON CONFLICT DO NOTHING;

-- Mostrar resumen
SELECT 'Localidades cargadas: ' || COUNT(*) FROM localidades;
EOSQL
    
    print_success "Localidades cargadas correctamente"
}

# Función para cargar datos de ejemplo de indicadores
cargar_indicadores_ejemplo() {
    print_step "Cargando indicadores de ejemplo..."
    
    local csv_file="${DATA_DIR}/ejemplo_indicadores.csv"
    
    if [ ! -f "$csv_file" ]; then
        print_error "No se encontró el archivo $csv_file"
        return 1
    fi
    
    # Validar que el archivo está en el directorio esperado
    local real_path
    real_path=$(realpath "$csv_file")
    local expected_dir
    expected_dir=$(realpath "$DATA_DIR")
    
    if [[ ! "$real_path" =~ ^"$expected_dir" ]]; then
        print_error "El archivo no está en el directorio esperado: $DATA_DIR"
        return 1
    fi
    
    # Crear tabla temporal y cargar CSV
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Crear tabla temporal para importar CSV
CREATE TEMP TABLE indicadores_temp (
    localidad VARCHAR(200),
    fecha DATE,
    tipo_indicador VARCHAR(100),
    subtipo VARCHAR(100),
    valor DECIMAL(10,2),
    descripcion TEXT
);
EOSQL

    # Cargar CSV usando COPY
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" \
        -c "\\copy indicadores_temp FROM '${csv_file}' WITH (FORMAT csv, HEADER true, DELIMITER ',')"
    
    # Insertar en tabla final
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Insertar indicadores vinculando con localidades
INSERT INTO indicadores_adicciones (localidad_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT 
    l.id,
    i.fecha,
    i.tipo_indicador,
    i.subtipo,
    i.valor,
    i.descripcion,
    l.ubicacion
FROM indicadores_temp i
LEFT JOIN localidades l ON LOWER(TRIM(l.nombre)) = LOWER(TRIM(i.localidad));

-- Mostrar resumen por tipo de indicador
SELECT tipo_indicador, COUNT(*) as cantidad 
FROM indicadores_adicciones 
GROUP BY tipo_indicador
ORDER BY cantidad DESC;
EOSQL
    
    print_success "Indicadores de ejemplo cargados correctamente"
}

# Función para cargar datos censales de ejemplo
cargar_datos_censales() {
    print_step "Cargando datos censales de ejemplo..."
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Insertar datos censales para algunos departamentos (Censo 2022 - datos aproximados)
INSERT INTO datos_censo (zona_id, anio, poblacion_total, poblacion_masculina, poblacion_femenina, hogares, viviendas)
SELECT 
    z.id,
    2022,
    CASE 
        WHEN z.nombre = 'Capital' THEN 1330023
        WHEN z.nombre = 'Río Cuarto' THEN 246393
        WHEN z.nombre = 'San Justo' THEN 206307
        WHEN z.nombre = 'Punilla' THEN 178401
        WHEN z.nombre = 'Colón' THEN 225151
        WHEN z.nombre = 'General San Martín' THEN 127454
        WHEN z.nombre = 'Tercero Arriba' THEN 109554
        WHEN z.nombre = 'Río Segundo' THEN 103718
        WHEN z.nombre = 'Marcos Juárez' THEN 104205
        WHEN z.nombre = 'Unión' THEN 105727
        ELSE 50000
    END as poblacion_total,
    CASE 
        WHEN z.nombre = 'Capital' THEN 630000
        WHEN z.nombre = 'Río Cuarto' THEN 118000
        ELSE 24000
    END as poblacion_masculina,
    CASE 
        WHEN z.nombre = 'Capital' THEN 700023
        WHEN z.nombre = 'Río Cuarto' THEN 128393
        ELSE 26000
    END as poblacion_femenina,
    CASE 
        WHEN z.nombre = 'Capital' THEN 450000
        WHEN z.nombre = 'Río Cuarto' THEN 85000
        ELSE 17000
    END as hogares,
    CASE 
        WHEN z.nombre = 'Capital' THEN 500000
        WHEN z.nombre = 'Río Cuarto' THEN 95000
        ELSE 19000
    END as viviendas
FROM zonas_geograficas z
WHERE z.tipo = 'departamento' AND z.codigo_padre = 'AR-X'
ON CONFLICT (zona_id, anio) DO UPDATE SET
    poblacion_total = EXCLUDED.poblacion_total,
    poblacion_masculina = EXCLUDED.poblacion_masculina,
    poblacion_femenina = EXCLUDED.poblacion_femenina,
    hogares = EXCLUDED.hogares,
    viviendas = EXCLUDED.viviendas;

-- Mostrar resumen
SELECT 'Datos censales cargados para ' || COUNT(*) || ' departamentos' FROM datos_censo WHERE anio = 2022;
EOSQL
    
    print_success "Datos censales cargados correctamente"
}

# Función para mostrar resumen final
mostrar_resumen() {
    print_header "RESUMEN DE CARGA DE DATOS"
    
    PGPASSWORD="$DB_PASS" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" <<EOSQL
-- Resumen de datos cargados
SELECT '📍 Zonas geográficas' as tabla, COUNT(*) as registros FROM zonas_geograficas
UNION ALL
SELECT '🏘️ Localidades' as tabla, COUNT(*) FROM localidades
UNION ALL
SELECT '📊 Indicadores' as tabla, COUNT(*) FROM indicadores_adicciones
UNION ALL
SELECT '📈 Datos censales' as tabla, COUNT(*) FROM datos_censo
UNION ALL
SELECT '🏥 Centros de atención' as tabla, COUNT(*) FROM centros_atencion;
EOSQL
}

# =============================================================================
# Función principal
# =============================================================================

main() {
    print_header "CARGA DE DATOS INICIALES - CÓRDOBA"
    
    echo "Configuración:"
    echo "  - Host: $DB_HOST"
    echo "  - Puerto: $DB_PORT"
    echo "  - Base de datos: $DB_NAME"
    echo "  - Usuario: $DB_USER"
    echo "  - Directorio de datos: $DATA_DIR"
    echo ""
    
    # Verificar que los archivos existan
    if [ ! -d "$CORDOBA_DIR" ]; then
        print_error "No se encontró el directorio $CORDOBA_DIR"
        exit 1
    fi
    
    # Esperar a que PostGIS esté listo
    wait_for_postgis || exit 1
    
    # Cargar datos
    print_header "CARGANDO DATOS GEOGRÁFICOS"
    cargar_departamentos
    cargar_regiones_sanitarias
    cargar_localidades
    
    print_header "CARGANDO DATOS DE EJEMPLO"
    cargar_indicadores_ejemplo
    cargar_datos_censales
    
    # Mostrar resumen
    mostrar_resumen
    
    echo ""
    print_success "¡Carga de datos completada exitosamente!"
    echo ""
    echo "Próximos pasos:"
    echo "  1. Acceder a pgAdmin en http://localhost:5050"
    echo "  2. Verificar los datos en las tablas"
    echo "  3. Configurar capas en GeoServer: http://localhost:8080/geoserver"
    echo "  4. Visualizar mapas en Kepler.gl: http://localhost:8081"
    echo ""
}

# Ejecutar
main "$@"
