-- Script de inicialización de la base de datos GIS para Indicadores de Adicciones
-- Este script crea las tablas, índices espaciales y funciones necesarias

-- Habilitar extensión PostGIS (ya viene habilitada en la imagen, pero por seguridad)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- ============================================================================
-- TABLA: zonas_geograficas
-- Almacena las divisiones geográficas (provincias, departamentos, localidades)
-- ============================================================================
CREATE TABLE IF NOT EXISTS zonas_geograficas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('provincia', 'departamento', 'localidad')),
    codigo_padre VARCHAR(20),
    geom GEOMETRY(MULTIPOLYGON, 4326),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice espacial para búsquedas geográficas eficientes
CREATE INDEX IF NOT EXISTS idx_zonas_geograficas_geom ON zonas_geograficas USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_zonas_geograficas_tipo ON zonas_geograficas (tipo);
CREATE INDEX IF NOT EXISTS idx_zonas_geograficas_codigo ON zonas_geograficas (codigo);

-- ============================================================================
-- TABLA: datos_censo
-- Almacena datos censales por zona geográfica
-- ============================================================================
CREATE TABLE IF NOT EXISTS datos_censo (
    id SERIAL PRIMARY KEY,
    zona_id INTEGER NOT NULL REFERENCES zonas_geograficas(id) ON DELETE CASCADE,
    anio INTEGER NOT NULL,
    poblacion_total INTEGER,
    poblacion_masculina INTEGER,
    poblacion_femenina INTEGER,
    hogares INTEGER,
    viviendas INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(zona_id, anio)
);

CREATE INDEX IF NOT EXISTS idx_datos_censo_zona ON datos_censo (zona_id);
CREATE INDEX IF NOT EXISTS idx_datos_censo_anio ON datos_censo (anio);

-- ============================================================================
-- TABLA: indicadores_adicciones
-- Almacena indicadores relacionados con adicciones por zona y fecha
-- ============================================================================
CREATE TABLE IF NOT EXISTS indicadores_adicciones (
    id SERIAL PRIMARY KEY,
    zona_id INTEGER NOT NULL REFERENCES zonas_geograficas(id) ON DELETE CASCADE,
    fecha DATE NOT NULL,
    tipo_indicador VARCHAR(30) NOT NULL CHECK (tipo_indicador IN ('consumo', 'tratamiento', 'prevencion')),
    valor NUMERIC(12, 2) NOT NULL,
    descripcion TEXT,
    ubicacion GEOMETRY(POINT, 4326),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para búsquedas eficientes
CREATE INDEX IF NOT EXISTS idx_indicadores_zona ON indicadores_adicciones (zona_id);
CREATE INDEX IF NOT EXISTS idx_indicadores_fecha ON indicadores_adicciones (fecha);
CREATE INDEX IF NOT EXISTS idx_indicadores_tipo ON indicadores_adicciones (tipo_indicador);
CREATE INDEX IF NOT EXISTS idx_indicadores_ubicacion ON indicadores_adicciones USING GIST (ubicacion);

-- ============================================================================
-- TABLA: centros_atencion
-- Almacena información de centros de atención y tratamiento
-- ============================================================================
CREATE TABLE IF NOT EXISTS centros_atencion (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    direccion VARCHAR(300),
    telefono VARCHAR(50),
    tipo VARCHAR(50) NOT NULL,
    ubicacion GEOMETRY(POINT, 4326),
    zona_id INTEGER REFERENCES zonas_geograficas(id) ON DELETE SET NULL,
    activo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices espaciales y de búsqueda
CREATE INDEX IF NOT EXISTS idx_centros_ubicacion ON centros_atencion USING GIST (ubicacion);
CREATE INDEX IF NOT EXISTS idx_centros_zona ON centros_atencion (zona_id);
CREATE INDEX IF NOT EXISTS idx_centros_tipo ON centros_atencion (tipo);

-- ============================================================================
-- FUNCIONES ÚTILES
-- ============================================================================

-- Función para encontrar la zona geográfica de un punto
CREATE OR REPLACE FUNCTION encontrar_zona(punto GEOMETRY)
RETURNS TABLE(zona_id INTEGER, zona_nombre VARCHAR, zona_tipo VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT z.id, z.nombre, z.tipo
    FROM zonas_geograficas z
    WHERE ST_Contains(z.geom, punto)
    ORDER BY 
        CASE z.tipo 
            WHEN 'localidad' THEN 1 
            WHEN 'departamento' THEN 2 
            WHEN 'provincia' THEN 3 
        END;
END;
$$ LANGUAGE plpgsql;

-- Función para calcular estadísticas de indicadores por zona
CREATE OR REPLACE FUNCTION estadisticas_zona(p_zona_id INTEGER, p_fecha_inicio DATE, p_fecha_fin DATE)
RETURNS TABLE(
    tipo VARCHAR,
    cantidad BIGINT,
    suma NUMERIC,
    promedio NUMERIC,
    minimo NUMERIC,
    maximo NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.tipo_indicador::VARCHAR,
        COUNT(*)::BIGINT,
        SUM(i.valor),
        AVG(i.valor),
        MIN(i.valor),
        MAX(i.valor)
    FROM indicadores_adicciones i
    WHERE i.zona_id = p_zona_id
      AND i.fecha BETWEEN p_fecha_inicio AND p_fecha_fin
    GROUP BY i.tipo_indicador;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener indicadores cercanos a un punto
CREATE OR REPLACE FUNCTION indicadores_cercanos(
    punto GEOMETRY,
    radio_metros INTEGER DEFAULT 5000,
    limite INTEGER DEFAULT 100
)
RETURNS TABLE(
    indicador_id INTEGER,
    tipo VARCHAR,
    valor NUMERIC,
    fecha DATE,
    distancia_metros DOUBLE PRECISION
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        i.id,
        i.tipo_indicador::VARCHAR,
        i.valor,
        i.fecha,
        ST_Distance(i.ubicacion::geography, punto::geography) as distancia
    FROM indicadores_adicciones i
    WHERE i.ubicacion IS NOT NULL
      AND ST_DWithin(i.ubicacion::geography, punto::geography, radio_metros)
    ORDER BY distancia
    LIMIT limite;
END;
$$ LANGUAGE plpgsql;

-- Vista para resumen de indicadores por provincia
CREATE OR REPLACE VIEW vista_resumen_provincias AS
SELECT 
    z.id as zona_id,
    z.codigo,
    z.nombre as provincia,
    z.geom,
    COUNT(i.id) as total_indicadores,
    SUM(CASE WHEN i.tipo_indicador = 'consumo' THEN 1 ELSE 0 END) as indicadores_consumo,
    SUM(CASE WHEN i.tipo_indicador = 'tratamiento' THEN 1 ELSE 0 END) as indicadores_tratamiento,
    SUM(CASE WHEN i.tipo_indicador = 'prevencion' THEN 1 ELSE 0 END) as indicadores_prevencion,
    dc.poblacion_total as poblacion_ultimo_censo
FROM zonas_geograficas z
LEFT JOIN indicadores_adicciones i ON z.id = i.zona_id
LEFT JOIN datos_censo dc ON z.id = dc.zona_id AND dc.anio = (
    SELECT MAX(anio) FROM datos_censo WHERE zona_id = z.id
)
WHERE z.tipo = 'provincia'
GROUP BY z.id, z.codigo, z.nombre, z.geom, dc.poblacion_total;

-- Mensaje de confirmación
DO $$
BEGIN
    RAISE NOTICE 'Base de datos inicializada correctamente con tablas, índices y funciones.';
END $$;
