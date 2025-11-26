-- Script de inicialización de la base de datos GIS para Indicadores de Adicciones
-- Este script crea las tablas, índices espaciales y funciones necesarias

-- Habilitar extensión PostGIS (ya viene habilitada en la imagen, pero por seguridad)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;

-- ============================================================================
-- TABLA: zonas_geograficas
-- Almacena las divisiones geográficas (provincias, departamentos, regiones sanitarias, barrios, localidades)
-- ============================================================================
CREATE TABLE IF NOT EXISTS zonas_geograficas (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20) UNIQUE,
    nombre VARCHAR(200) NOT NULL,
    tipo VARCHAR(50) NOT NULL, -- 'provincia', 'departamento', 'region_sanitaria', 'barrio', 'localidad'
    codigo_padre VARCHAR(20),
    geom GEOMETRY(MULTIPOLYGON, 4326),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice espacial para búsquedas geográficas eficientes
CREATE INDEX IF NOT EXISTS idx_zonas_geom ON zonas_geograficas USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_zonas_geograficas_tipo ON zonas_geograficas (tipo);
CREATE INDEX IF NOT EXISTS idx_zonas_geograficas_codigo ON zonas_geograficas (codigo);

-- ============================================================================
-- TABLA: localidades
-- Almacena localidades con coordenadas puntuales
-- ============================================================================
CREATE TABLE IF NOT EXISTS localidades (
    id SERIAL PRIMARY KEY,
    codigo VARCHAR(20),
    nombre VARCHAR(200) NOT NULL,
    departamento VARCHAR(200),
    latitud DECIMAL(10,6),
    longitud DECIMAL(10,6),
    ubicacion GEOMETRY(POINT, 4326),
    poblacion INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índice espacial para localidades
CREATE INDEX IF NOT EXISTS idx_localidades_ubicacion ON localidades USING GIST (ubicacion);
CREATE INDEX IF NOT EXISTS idx_localidades_nombre ON localidades (nombre);
CREATE INDEX IF NOT EXISTS idx_localidades_departamento ON localidades (departamento);

-- ============================================================================
-- TABLA: datos_censo
-- Almacena datos censales por zona geográfica
-- ============================================================================
CREATE TABLE IF NOT EXISTS datos_censo (
    id SERIAL PRIMARY KEY,
    zona_id INTEGER REFERENCES zonas_geograficas(id) ON DELETE CASCADE,
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
-- Almacena indicadores relacionados con adicciones por zona/localidad y fecha
-- ============================================================================
CREATE TABLE IF NOT EXISTS indicadores_adicciones (
    id SERIAL PRIMARY KEY,
    localidad_id INTEGER REFERENCES localidades(id) ON DELETE SET NULL,
    zona_id INTEGER REFERENCES zonas_geograficas(id) ON DELETE SET NULL,
    fecha DATE NOT NULL,
    tipo_indicador VARCHAR(100), -- 'consumo', 'tratamiento', 'prevencion', 'consulta'
    subtipo VARCHAR(100),
    valor DECIMAL(10,2),
    descripcion TEXT,
    ubicacion GEOMETRY(POINT, 4326),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para búsquedas eficientes
CREATE INDEX IF NOT EXISTS idx_indicadores_localidad ON indicadores_adicciones (localidad_id);
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
    direccion TEXT,
    localidad VARCHAR(200),
    telefono VARCHAR(50),
    tipo VARCHAR(100), -- 'hospital', 'centro_salud', 'CPA', 'comunidad_terapeutica'
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
    SELECT z.id, z.nombre::VARCHAR, z.tipo::VARCHAR
    FROM zonas_geograficas z
    WHERE ST_Contains(z.geom, punto)
    ORDER BY 
        CASE z.tipo 
            WHEN 'localidad' THEN 1 
            WHEN 'barrio' THEN 2
            WHEN 'departamento' THEN 3 
            WHEN 'region_sanitaria' THEN 4
            WHEN 'provincia' THEN 5 
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

-- Vista para resumen de indicadores por departamento de Córdoba
CREATE OR REPLACE VIEW vista_resumen_departamentos_cordoba AS
SELECT 
    z.id as zona_id,
    z.codigo,
    z.nombre as departamento,
    z.geom,
    COUNT(i.id) as total_indicadores,
    SUM(CASE WHEN i.tipo_indicador = 'consumo' THEN 1 ELSE 0 END) as indicadores_consumo,
    SUM(CASE WHEN i.tipo_indicador = 'tratamiento' THEN 1 ELSE 0 END) as indicadores_tratamiento,
    SUM(CASE WHEN i.tipo_indicador = 'prevencion' THEN 1 ELSE 0 END) as indicadores_prevencion,
    SUM(CASE WHEN i.tipo_indicador = 'consulta' THEN 1 ELSE 0 END) as indicadores_consulta,
    dc.poblacion_total as poblacion_ultimo_censo
FROM zonas_geograficas z
LEFT JOIN indicadores_adicciones i ON z.id = i.zona_id
LEFT JOIN datos_censo dc ON z.id = dc.zona_id AND dc.anio = (
    SELECT MAX(anio) FROM datos_censo WHERE zona_id = z.id
)
WHERE z.tipo = 'departamento' AND z.codigo_padre = 'AR-X'
GROUP BY z.id, z.codigo, z.nombre, z.geom, dc.poblacion_total;

-- ============================================================================
-- DATOS INICIALES DE EJEMPLO
-- ============================================================================

-- ============================================================================
-- 1. PROVINCIA CÓRDOBA
-- ============================================================================
INSERT INTO zonas_geograficas (codigo, nombre, tipo, codigo_padre, geom) VALUES
('AR-X', 'Córdoba', 'provincia', NULL, ST_Multi(ST_GeomFromText('POLYGON((-65.5 -29.5, -65.5 -35.0, -61.5 -35.0, -61.5 -29.5, -65.5 -29.5))', 4326)));

-- ============================================================================
-- 2. DEPARTAMENTOS (26)
-- ============================================================================
INSERT INTO zonas_geograficas (codigo, nombre, tipo, codigo_padre, geom) VALUES
('14007', 'Capital', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.30 -31.30, -64.30 -31.50, -64.10 -31.50, -64.10 -31.30, -64.30 -31.30))', 4326))),
('14014', 'Río Cuarto', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.80 -32.80, -64.80 -33.50, -63.80 -33.50, -63.80 -32.80, -64.80 -32.80))', 4326))),
('14021', 'San Justo', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-62.50 -30.80, -62.50 -31.80, -61.80 -31.80, -61.80 -30.80, -62.50 -30.80))', 4326))),
('14028', 'Punilla', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.70 -30.80, -64.70 -31.40, -64.30 -31.40, -64.30 -30.80, -64.70 -30.80))', 4326))),
('14035', 'Colón', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.40 -30.80, -64.40 -31.30, -63.90 -31.30, -63.90 -30.80, -64.40 -30.80))', 4326))),
('14042', 'General San Martín', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.60 -32.20, -63.60 -32.60, -62.90 -32.60, -62.90 -32.20, -63.60 -32.20))', 4326))),
('14049', 'Tercero Arriba', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.30 -32.00, -64.30 -32.50, -63.70 -32.50, -63.70 -32.00, -64.30 -32.00))', 4326))),
('14056', 'Río Segundo', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.60 -31.40, -63.60 -32.00, -62.90 -32.00, -62.90 -31.40, -63.60 -31.40))', 4326))),
('14063', 'Marcos Juárez', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-62.80 -32.40, -62.80 -33.20, -62.00 -33.20, -62.00 -32.40, -62.80 -32.40))', 4326))),
('14070', 'Unión', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.00 -32.50, -63.00 -33.20, -62.20 -33.20, -62.20 -32.50, -63.00 -32.50))', 4326))),
('14077', 'General Roca', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.00 -33.80, -65.00 -34.80, -64.00 -34.80, -64.00 -33.80, -65.00 -33.80))', 4326))),
('14084', 'Juárez Celman', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.80 -33.00, -63.80 -33.60, -62.90 -33.60, -62.90 -33.00, -63.80 -33.00))', 4326))),
('14091', 'Presidente Roque Sáenz Peña', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.60 -33.60, -63.60 -34.40, -62.80 -34.40, -62.80 -33.60, -63.60 -33.60))', 4326))),
('14098', 'Santa María', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.50 -31.50, -64.50 -32.20, -63.90 -32.20, -63.90 -31.50, -64.50 -31.50))', 4326))),
('14105', 'Cruz del Eje', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.30 -30.40, -65.30 -31.10, -64.50 -31.10, -64.50 -30.40, -65.30 -30.40))', 4326))),
('14112', 'San Alberto', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.10 -31.40, -65.10 -32.00, -64.50 -32.00, -64.50 -31.40, -65.10 -31.40))', 4326))),
('14119', 'Calamuchita', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.80 -31.80, -64.80 -32.50, -64.20 -32.50, -64.20 -31.80, -64.80 -31.80))', 4326))),
('14126', 'Río Primero', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.70 -30.80, -63.70 -31.50, -63.00 -31.50, -63.00 -30.80, -63.70 -30.80))', 4326))),
('14133', 'Totoral', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.10 -30.50, -64.10 -31.00, -63.50 -31.00, -63.50 -30.50, -64.10 -30.50))', 4326))),
('14140', 'Ischilín', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.60 -30.10, -64.60 -30.70, -64.00 -30.70, -64.00 -30.10, -64.60 -30.10))', 4326))),
('14147', 'Tulumba', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.00 -29.80, -64.00 -30.60, -63.30 -30.60, -63.30 -29.80, -64.00 -29.80))', 4326))),
('14154', 'Sobremonte', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.20 -29.50, -64.20 -30.10, -63.60 -30.10, -63.60 -29.50, -64.20 -29.50))', 4326))),
('14161', 'Río Seco', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.50 -29.60, -63.50 -30.40, -62.80 -30.40, -62.80 -29.60, -63.50 -29.60))', 4326))),
('14168', 'Pocho', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.40 -31.00, -65.40 -31.60, -64.80 -31.60, -64.80 -31.00, -65.40 -31.00))', 4326))),
('14175', 'Minas', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.30 -30.80, -65.30 -31.30, -64.70 -31.30, -64.70 -30.80, -65.30 -30.80))', 4326))),
('14182', 'San Javier', 'departamento', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.40 -31.60, -65.40 -32.40, -64.80 -32.40, -64.80 -31.60, -65.40 -31.60))', 4326)));

-- ============================================================================
-- 3. REGIONES SANITARIAS (14)
-- ============================================================================
INSERT INTO zonas_geograficas (codigo, nombre, tipo, codigo_padre, geom) VALUES
('RS01', 'Región Sanitaria Capital', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.35 -31.25, -64.35 -31.55, -64.05 -31.55, -64.05 -31.25, -64.35 -31.25))', 4326))),
('RS02', 'Región Sanitaria Punilla', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.75 -30.75, -64.75 -31.45, -64.25 -31.45, -64.25 -30.75, -64.75 -30.75))', 4326))),
('RS03', 'Región Sanitaria Colón', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.45 -30.45, -64.45 -31.35, -63.45 -31.35, -63.45 -30.45, -64.45 -30.45))', 4326))),
('RS04', 'Región Sanitaria Norte', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.65 -29.45, -64.65 -30.75, -62.75 -30.75, -62.75 -29.45, -64.65 -29.45))', 4326))),
('RS05', 'Región Sanitaria Cruz del Eje', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.50 -30.35, -65.50 -31.65, -64.45 -31.65, -64.45 -30.35, -65.50 -30.35))', 4326))),
('RS06', 'Región Sanitaria Traslasierra', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.50 -31.35, -65.50 -32.45, -64.45 -32.45, -64.45 -31.35, -65.50 -31.35))', 4326))),
('RS07', 'Región Sanitaria Santa María', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.85 -31.45, -64.85 -32.55, -63.85 -32.55, -63.85 -31.45, -64.85 -31.45))', 4326))),
('RS08', 'Región Sanitaria Río Segundo', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.75 -30.75, -63.75 -32.05, -62.85 -32.05, -62.85 -30.75, -63.75 -30.75))', 4326))),
('RS09', 'Región Sanitaria Tercero Arriba', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.35 -31.95, -64.35 -32.55, -63.65 -32.55, -63.65 -31.95, -64.35 -31.95))', 4326))),
('RS10', 'Región Sanitaria San Justo', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-62.55 -30.75, -62.55 -31.85, -61.75 -31.85, -61.75 -30.75, -62.55 -30.75))', 4326))),
('RS11', 'Región Sanitaria Unión', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.05 -32.35, -63.05 -33.25, -61.95 -33.25, -61.95 -32.35, -63.05 -32.35))', 4326))),
('RS12', 'Región Sanitaria General San Martín', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-63.85 -32.15, -63.85 -33.65, -62.85 -33.65, -62.85 -32.15, -63.85 -32.15))', 4326))),
('RS13', 'Región Sanitaria Río Cuarto', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-64.85 -32.75, -64.85 -33.55, -63.75 -33.55, -63.75 -32.75, -64.85 -32.75))', 4326))),
('RS14', 'Región Sanitaria Sur', 'region_sanitaria', 'AR-X', ST_Multi(ST_GeomFromText('POLYGON((-65.05 -33.55, -65.05 -34.85, -62.75 -34.85, -62.75 -33.55, -65.05 -33.55))', 4326)));

-- ============================================================================
-- 4. LOCALIDADES (56)
-- ============================================================================
INSERT INTO localidades (codigo, nombre, departamento, latitud, longitud, ubicacion, poblacion) VALUES
('14014010', 'Córdoba', 'Capital', -31.4201, -64.1888, ST_SetSRID(ST_MakePoint(-64.1888, -31.4201), 4326), 1330023),
('14098010', 'Río Cuarto', 'Río Cuarto', -33.1307, -64.3499, ST_SetSRID(ST_MakePoint(-64.3499, -33.1307), 4326), 158298),
('14126010', 'Villa María', 'General San Martín', -32.4074, -63.2429, ST_SetSRID(ST_MakePoint(-63.2429, -32.4074), 4326), 80006),
('14021010', 'San Francisco', 'San Justo', -31.4281, -62.0828, ST_SetSRID(ST_MakePoint(-62.0828, -31.4281), 4326), 62211),
('14028010', 'Carlos Paz', 'Punilla', -31.4241, -64.4979, ST_SetSRID(ST_MakePoint(-64.4979, -31.4241), 4326), 62750),
('14035010', 'Alta Gracia', 'Santa María', -31.6596, -64.4298, ST_SetSRID(ST_MakePoint(-64.4298, -31.6596), 4326), 48506),
('14014020', 'Río Tercero', 'Tercero Arriba', -32.1737, -64.1144, ST_SetSRID(ST_MakePoint(-64.1144, -32.1737), 4326), 46421),
('14035020', 'Jesús María', 'Colón', -30.9816, -64.0953, ST_SetSRID(ST_MakePoint(-64.0953, -30.9816), 4326), 31602),
('14070010', 'Bell Ville', 'Unión', -32.6277, -62.6889, ST_SetSRID(ST_MakePoint(-62.6889, -32.6277), 4326), 34439),
('14105010', 'Cruz del Eje', 'Cruz del Eje', -30.7269, -64.8063, ST_SetSRID(ST_MakePoint(-64.8063, -30.7269), 4326), 30680),
('14063010', 'Marcos Juárez', 'Marcos Juárez', -32.6908, -62.1057, ST_SetSRID(ST_MakePoint(-62.1057, -32.6908), 4326), 27004),
('14056010', 'Villa del Rosario', 'Río Segundo', -31.5607, -63.5349, ST_SetSRID(ST_MakePoint(-63.5349, -31.5607), 4326), 16299),
('14028020', 'Cosquín', 'Punilla', -31.2436, -64.4664, ST_SetSRID(ST_MakePoint(-64.4664, -31.2436), 4326), 19458),
('14140010', 'Deán Funes', 'Ischilín', -30.4268, -64.3507, ST_SetSRID(ST_MakePoint(-64.3507, -30.4268), 4326), 21508),
('14084010', 'La Carlota', 'Juárez Celman', -33.4178, -63.2967, ST_SetSRID(ST_MakePoint(-63.2967, -33.4178), 4326), 12094),
('14182010', 'Villa Dolores', 'San Javier', -31.9442, -65.1890, ST_SetSRID(ST_MakePoint(-65.1890, -31.9442), 4326), 29117),
('14098020', 'La Calera', 'Colón', -31.3439, -64.3347, ST_SetSRID(ST_MakePoint(-64.3347, -31.3439), 4326), 32227),
('14119010', 'Santa Rosa de Calamuchita', 'Calamuchita', -32.0669, -64.5364, ST_SetSRID(ST_MakePoint(-64.5364, -32.0669), 4326), 11727),
('14091010', 'Laboulaye', 'Presidente Roque Sáenz Peña', -34.1269, -63.3911, ST_SetSRID(ST_MakePoint(-63.3911, -34.1269), 4326), 21296),
('14077010', 'Villa Huidobro', 'General Roca', -34.8389, -64.5833, ST_SetSRID(ST_MakePoint(-64.5833, -34.8389), 4326), 5859),
('14126020', 'Santa Rosa de Río Primero', 'Río Primero', -31.1530, -63.4075, ST_SetSRID(ST_MakePoint(-63.4075, -31.1530), 4326), 8795),
('14133010', 'Villa del Totoral', 'Totoral', -30.8142, -64.0031, ST_SetSRID(ST_MakePoint(-64.0031, -30.8142), 4326), 6833),
('14112010', 'Villa Cura Brochero', 'San Alberto', -31.7064, -65.0186, ST_SetSRID(ST_MakePoint(-65.0186, -31.7064), 4326), 5438),
('14147010', 'Villa Tulumba', 'Tulumba', -30.3994, -64.1269, ST_SetSRID(ST_MakePoint(-64.1269, -30.3994), 4326), 1825),
('14154010', 'San Francisco del Chañar', 'Sobremonte', -29.7881, -63.9442, ST_SetSRID(ST_MakePoint(-63.9442, -29.7881), 4326), 2619),
('14161010', 'Villa de María', 'Río Seco', -29.8983, -63.7178, ST_SetSRID(ST_MakePoint(-63.7178, -29.8983), 4326), 6161),
('14168010', 'Salsacate', 'Pocho', -31.3167, -65.0833, ST_SetSRID(ST_MakePoint(-65.0833, -31.3167), 4326), 1827),
('14175010', 'San Carlos Minas', 'Minas', -31.1750, -65.0917, ST_SetSRID(ST_MakePoint(-65.0917, -31.1750), 4326), 1235),
('14028030', 'La Falda', 'Punilla', -31.0905, -64.4930, ST_SetSRID(ST_MakePoint(-64.4930, -31.0905), 4326), 18008),
('14028040', 'Villa Giardino', 'Punilla', -31.0397, -64.5006, ST_SetSRID(ST_MakePoint(-64.5006, -31.0397), 4326), 6769),
('14028050', 'Huerta Grande', 'Punilla', -31.0716, -64.4903, ST_SetSRID(ST_MakePoint(-64.4903, -31.0716), 4326), 4768),
('14014030', 'Unquillo', 'Colón', -31.2308, -64.3142, ST_SetSRID(ST_MakePoint(-64.3142, -31.2308), 4326), 18483),
('14014040', 'Río Ceballos', 'Colón', -31.1656, -64.3239, ST_SetSRID(ST_MakePoint(-64.3239, -31.1656), 4326), 20242),
('14014050', 'Saldán', 'Colón', -31.3069, -64.3142, ST_SetSRID(ST_MakePoint(-64.3142, -31.3069), 4326), 2985),
('14035030', 'Villa Allende', 'Colón', -31.2936, -64.2958, ST_SetSRID(ST_MakePoint(-64.2958, -31.2936), 4326), 28374),
('14035040', 'Mendiolaza', 'Colón', -31.2592, -64.3003, ST_SetSRID(ST_MakePoint(-64.3003, -31.2592), 4326), 11466),
('14098030', 'Almafuerte', 'Tercero Arriba', -32.1919, -64.2492, ST_SetSRID(ST_MakePoint(-64.2492, -32.1919), 4326), 11465),
('14098040', 'Embalse', 'Calamuchita', -32.1833, -64.4167, ST_SetSRID(ST_MakePoint(-64.4167, -32.1833), 4326), 8211),
('14014060', 'Pilar', 'Río Segundo', -31.6756, -63.8825, ST_SetSRID(ST_MakePoint(-63.8825, -31.6756), 4326), 14426),
('14021020', 'Morteros', 'San Justo', -30.7139, -62.0044, ST_SetSRID(ST_MakePoint(-62.0044, -30.7139), 4326), 18606),
('14021030', 'Brinkmann', 'San Justo', -30.8661, -62.0389, ST_SetSRID(ST_MakePoint(-62.0389, -30.8661), 4326), 10507),
('14021040', 'Porteña', 'San Justo', -31.0133, -62.0686, ST_SetSRID(ST_MakePoint(-62.0686, -31.0133), 4326), 6085),
('14063020', 'General Baldissera', 'Marcos Juárez', -33.1200, -62.3000, ST_SetSRID(ST_MakePoint(-62.3000, -33.1200), 4326), 4826),
('14070020', 'Justiniano Posse', 'Unión', -32.8833, -62.6833, ST_SetSRID(ST_MakePoint(-62.6833, -32.8833), 4326), 8417),
('14070030', 'Canals', 'Unión', -33.5633, -62.8861, ST_SetSRID(ST_MakePoint(-62.8861, -33.5633), 4326), 10283),
('14084020', 'General Cabrera', 'Juárez Celman', -32.8192, -63.8756, ST_SetSRID(ST_MakePoint(-63.8756, -32.8192), 4326), 11372),
('14084030', 'General Deheza', 'Juárez Celman', -32.7544, -63.7900, ST_SetSRID(ST_MakePoint(-63.7900, -32.7544), 4326), 10016),
('14119020', 'Villa General Belgrano', 'Calamuchita', -31.9792, -64.5564, ST_SetSRID(ST_MakePoint(-64.5564, -31.9792), 4326), 8328),
('14119030', 'Los Reartes', 'Calamuchita', -31.9061, -64.5856, ST_SetSRID(ST_MakePoint(-64.5856, -31.9061), 4326), 2000),
('14105020', 'Villa de Soto', 'Cruz del Eje', -30.8558, -64.9942, ST_SetSRID(ST_MakePoint(-64.9942, -30.8558), 4326), 7100),
('14126030', 'Villa Nueva', 'General San Martín', -32.4333, -63.2500, ST_SetSRID(ST_MakePoint(-63.2500, -32.4333), 4326), 18158),
('14126040', 'Laguna Larga', 'Río Segundo', -31.7817, -63.7967, ST_SetSRID(ST_MakePoint(-63.7967, -31.7817), 4326), 8000),
('14140020', 'Quilino', 'Ischilín', -30.2167, -64.5000, ST_SetSRID(ST_MakePoint(-64.5000, -30.2167), 4326), 5200),
('14182020', 'San Javier', 'San Javier', -31.9833, -65.0500, ST_SetSRID(ST_MakePoint(-65.0500, -31.9833), 4326), 2800),
('14182030', 'Yacanto', 'San Javier', -32.0333, -65.1000, ST_SetSRID(ST_MakePoint(-65.1000, -32.0333), 4326), 1500);

-- ============================================================================
-- 5. DATOS CENSALES (por departamento, datos aproximados de ejemplo)
-- ============================================================================
INSERT INTO datos_censo (zona_id, anio, poblacion_total, poblacion_masculina, poblacion_femenina, hogares, viviendas)
SELECT z.id, 2022, 
    CASE z.nombre
        WHEN 'Capital' THEN 1330023
        WHEN 'Río Cuarto' THEN 246393
        WHEN 'San Justo' THEN 206307
        WHEN 'Punilla' THEN 178401
        WHEN 'Colón' THEN 225151
        WHEN 'General San Martín' THEN 127454
        WHEN 'Tercero Arriba' THEN 109554
        WHEN 'Río Segundo' THEN 103718
        WHEN 'Marcos Juárez' THEN 104205
        WHEN 'Unión' THEN 105727
        WHEN 'General Roca' THEN 35645
        WHEN 'Juárez Celman' THEN 61078
        WHEN 'Presidente Roque Sáenz Peña' THEN 36391
        WHEN 'Santa María' THEN 96370
        WHEN 'Cruz del Eje' THEN 58759
        WHEN 'San Alberto' THEN 36308
        WHEN 'Calamuchita' THEN 54730
        WHEN 'Río Primero' THEN 46675
        WHEN 'Totoral' THEN 18556
        WHEN 'Ischilín' THEN 31312
        WHEN 'Tulumba' THEN 12571
        WHEN 'Sobremonte' THEN 4611
        WHEN 'Río Seco' THEN 13242
        WHEN 'Pocho' THEN 5380
        WHEN 'Minas' THEN 4727
        WHEN 'San Javier' THEN 53520
        ELSE 10000
    END as poblacion_total,
    CASE z.nombre
        WHEN 'Capital' THEN 638411
        ELSE (CASE z.nombre
            WHEN 'Río Cuarto' THEN 246393
            WHEN 'San Justo' THEN 206307
            ELSE 10000 END * 0.48)::integer
    END as poblacion_masculina,
    CASE z.nombre
        WHEN 'Capital' THEN 691612
        ELSE (CASE z.nombre
            WHEN 'Río Cuarto' THEN 246393
            WHEN 'San Justo' THEN 206307
            ELSE 10000 END * 0.52)::integer
    END as poblacion_femenina,
    CASE z.nombre
        WHEN 'Capital' THEN 450000
        ELSE 5000
    END as hogares,
    CASE z.nombre
        WHEN 'Capital' THEN 480000
        ELSE 5500
    END as viviendas
FROM zonas_geograficas z
WHERE z.tipo = 'departamento';

-- ============================================================================
-- 6. INDICADORES DE ADICCIONES (ejemplo de datos)
-- ============================================================================

-- Indicadores para Córdoba Capital
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-15'::date, 'consumo', 'alcohol', 156, 'Consultas por consumo problemático de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Capital' AND z.tipo = 'departamento'
WHERE l.nombre = 'Córdoba';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-20'::date, 'consumo', 'drogas', 89, 'Consultas por consumo de sustancias psicoactivas', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Capital' AND z.tipo = 'departamento'
WHERE l.nombre = 'Córdoba';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-01'::date, 'tratamiento', 'ambulatorio', 234, 'Pacientes en tratamiento ambulatorio activo', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Capital' AND z.tipo = 'departamento'
WHERE l.nombre = 'Córdoba';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-15'::date, 'tratamiento', 'internacion', 45, 'Pacientes en internación por adicciones', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Capital' AND z.tipo = 'departamento'
WHERE l.nombre = 'Córdoba';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-01'::date, 'prevencion', 'talleres', 28, 'Talleres de prevención realizados en escuelas', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Capital' AND z.tipo = 'departamento'
WHERE l.nombre = 'Córdoba';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-10'::date, 'consulta', 'orientacion', 312, 'Consultas de orientación familiar', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Capital' AND z.tipo = 'departamento'
WHERE l.nombre = 'Córdoba';

-- Indicadores para Río Cuarto
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-15'::date, 'consumo', 'alcohol', 78, 'Consultas por consumo problemático de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Río Cuarto' AND z.tipo = 'departamento'
WHERE l.nombre = 'Río Cuarto';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-25'::date, 'tratamiento', 'ambulatorio', 112, 'Pacientes en tratamiento ambulatorio', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Río Cuarto' AND z.tipo = 'departamento'
WHERE l.nombre = 'Río Cuarto';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-10'::date, 'prevencion', 'charlas', 15, 'Charlas preventivas en instituciones', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Río Cuarto' AND z.tipo = 'departamento'
WHERE l.nombre = 'Río Cuarto';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-28'::date, 'consulta', 'primera_vez', 67, 'Primeras consultas de pacientes nuevos', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Río Cuarto' AND z.tipo = 'departamento'
WHERE l.nombre = 'Río Cuarto';

-- Indicadores para Villa María
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-18'::date, 'consumo', 'drogas', 45, 'Consultas por consumo de sustancias', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'General San Martín' AND z.tipo = 'departamento'
WHERE l.nombre = 'Villa María';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-05'::date, 'tratamiento', 'ambulatorio', 89, 'Pacientes en seguimiento ambulatorio', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'General San Martín' AND z.tipo = 'departamento'
WHERE l.nombre = 'Villa María';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-20'::date, 'prevencion', 'talleres', 12, 'Talleres de prevención en barrios', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'General San Martín' AND z.tipo = 'departamento'
WHERE l.nombre = 'Villa María';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-15'::date, 'consulta', 'seguimiento', 156, 'Consultas de seguimiento de pacientes', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'General San Martín' AND z.tipo = 'departamento'
WHERE l.nombre = 'Villa María';

-- Indicadores para San Francisco
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-22'::date, 'consumo', 'alcohol', 34, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'San Justo' AND z.tipo = 'departamento'
WHERE l.nombre = 'San Francisco';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-12'::date, 'tratamiento', 'ambulatorio', 56, 'Pacientes en tratamiento activo', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'San Justo' AND z.tipo = 'departamento'
WHERE l.nombre = 'San Francisco';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-05'::date, 'prevencion', 'capacitacion', 8, 'Capacitaciones a profesionales de salud', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'San Justo' AND z.tipo = 'departamento'
WHERE l.nombre = 'San Francisco';

-- Indicadores para Carlos Paz
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-28'::date, 'consumo', 'drogas', 23, 'Consultas por consumo de sustancias', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Punilla' AND z.tipo = 'departamento'
WHERE l.nombre = 'Carlos Paz';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-18'::date, 'tratamiento', 'internacion', 12, 'Pacientes derivados a internación', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Punilla' AND z.tipo = 'departamento'
WHERE l.nombre = 'Carlos Paz';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-08'::date, 'consulta', 'orientacion', 45, 'Consultas de orientación', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Punilla' AND z.tipo = 'departamento'
WHERE l.nombre = 'Carlos Paz';

-- Indicadores para Alta Gracia
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-30'::date, 'consumo', 'alcohol', 28, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Santa María' AND z.tipo = 'departamento'
WHERE l.nombre = 'Alta Gracia';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-25'::date, 'tratamiento', 'ambulatorio', 34, 'Pacientes en tratamiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Santa María' AND z.tipo = 'departamento'
WHERE l.nombre = 'Alta Gracia';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-12'::date, 'prevencion', 'talleres', 6, 'Talleres preventivos realizados', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Santa María' AND z.tipo = 'departamento'
WHERE l.nombre = 'Alta Gracia';

-- Indicadores para Jesús María
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-01'::date, 'consumo', 'drogas', 18, 'Consultas por consumo de sustancias', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Colón' AND z.tipo = 'departamento'
WHERE l.nombre = 'Jesús María';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-20'::date, 'tratamiento', 'ambulatorio', 28, 'Pacientes en seguimiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Colón' AND z.tipo = 'departamento'
WHERE l.nombre = 'Jesús María';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-15'::date, 'consulta', 'primera_vez', 22, 'Primeras consultas', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Colón' AND z.tipo = 'departamento'
WHERE l.nombre = 'Jesús María';

-- Indicadores para Bell Ville
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-25'::date, 'consumo', 'alcohol', 25, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Unión' AND z.tipo = 'departamento'
WHERE l.nombre = 'Bell Ville';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-15'::date, 'tratamiento', 'ambulatorio', 38, 'Pacientes en tratamiento activo', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Unión' AND z.tipo = 'departamento'
WHERE l.nombre = 'Bell Ville';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-10'::date, 'prevencion', 'charlas', 5, 'Charlas preventivas', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Unión' AND z.tipo = 'departamento'
WHERE l.nombre = 'Bell Ville';

-- Indicadores para Cruz del Eje
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-05'::date, 'consumo', 'drogas', 15, 'Consultas por consumo de sustancias', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Cruz del Eje' AND z.tipo = 'departamento'
WHERE l.nombre = 'Cruz del Eje';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-28'::date, 'tratamiento', 'ambulatorio', 22, 'Pacientes en tratamiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Cruz del Eje' AND z.tipo = 'departamento'
WHERE l.nombre = 'Cruz del Eje';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-20'::date, 'consulta', 'orientacion', 18, 'Consultas de orientación familiar', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Cruz del Eje' AND z.tipo = 'departamento'
WHERE l.nombre = 'Cruz del Eje';

-- Indicadores para Villa Dolores
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-20'::date, 'consumo', 'alcohol', 20, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'San Javier' AND z.tipo = 'departamento'
WHERE l.nombre = 'Villa Dolores';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-10'::date, 'tratamiento', 'ambulatorio', 28, 'Pacientes en seguimiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'San Javier' AND z.tipo = 'departamento'
WHERE l.nombre = 'Villa Dolores';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-05'::date, 'prevencion', 'talleres', 4, 'Talleres en comunidades rurales', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'San Javier' AND z.tipo = 'departamento'
WHERE l.nombre = 'Villa Dolores';

-- Indicadores para Marcos Juárez
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-01'::date, 'consumo', 'alcohol', 16, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Marcos Juárez' AND z.tipo = 'departamento'
WHERE l.nombre = 'Marcos Juárez';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-22'::date, 'tratamiento', 'ambulatorio', 24, 'Pacientes en tratamiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Marcos Juárez' AND z.tipo = 'departamento'
WHERE l.nombre = 'Marcos Juárez';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-18'::date, 'consulta', 'seguimiento', 32, 'Consultas de seguimiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Marcos Juárez' AND z.tipo = 'departamento'
WHERE l.nombre = 'Marcos Juárez';

-- Indicadores para Deán Funes
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-28'::date, 'consumo', 'drogas', 12, 'Consultas por consumo de sustancias', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Ischilín' AND z.tipo = 'departamento'
WHERE l.nombre = 'Deán Funes';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-18'::date, 'tratamiento', 'ambulatorio', 18, 'Pacientes en tratamiento activo', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Ischilín' AND z.tipo = 'departamento'
WHERE l.nombre = 'Deán Funes';

-- Indicadores para La Carlota
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-08'::date, 'consumo', 'alcohol', 8, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Juárez Celman' AND z.tipo = 'departamento'
WHERE l.nombre = 'La Carlota';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-01'::date, 'prevencion', 'charlas', 3, 'Charlas preventivas', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Juárez Celman' AND z.tipo = 'departamento'
WHERE l.nombre = 'La Carlota';

-- Indicadores para Laboulaye
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-15'::date, 'consumo', 'alcohol', 10, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Presidente Roque Sáenz Peña' AND z.tipo = 'departamento'
WHERE l.nombre = 'Laboulaye';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-25'::date, 'tratamiento', 'ambulatorio', 15, 'Pacientes en tratamiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Presidente Roque Sáenz Peña' AND z.tipo = 'departamento'
WHERE l.nombre = 'Laboulaye';

-- Indicadores para Río Tercero
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-22'::date, 'consumo', 'drogas', 22, 'Consultas por consumo de sustancias', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Tercero Arriba' AND z.tipo = 'departamento'
WHERE l.nombre = 'Río Tercero';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-12'::date, 'tratamiento', 'ambulatorio', 35, 'Pacientes en tratamiento activo', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Tercero Arriba' AND z.tipo = 'departamento'
WHERE l.nombre = 'Río Tercero';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-03-08'::date, 'prevencion', 'talleres', 7, 'Talleres de prevención realizados', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Tercero Arriba' AND z.tipo = 'departamento'
WHERE l.nombre = 'Río Tercero';

-- Indicadores para Cosquín
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-05'::date, 'consumo', 'alcohol', 14, 'Consultas por consumo de alcohol', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Punilla' AND z.tipo = 'departamento'
WHERE l.nombre = 'Cosquín';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-28'::date, 'consulta', 'orientacion', 25, 'Consultas de orientación', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Punilla' AND z.tipo = 'departamento'
WHERE l.nombre = 'Cosquín';

-- Indicadores para La Calera
INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-01-30'::date, 'consumo', 'drogas', 18, 'Consultas por consumo de sustancias', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Colón' AND z.tipo = 'departamento'
WHERE l.nombre = 'La Calera';

INSERT INTO indicadores_adicciones (localidad_id, zona_id, fecha, tipo_indicador, subtipo, valor, descripcion, ubicacion)
SELECT l.id, z.id, '2024-02-20'::date, 'tratamiento', 'ambulatorio', 28, 'Pacientes en tratamiento', l.ubicacion
FROM localidades l
JOIN zonas_geograficas z ON z.nombre = 'Colón' AND z.tipo = 'departamento'
WHERE l.nombre = 'La Calera';

-- Mensaje de confirmación
DO $$
BEGIN
    RAISE NOTICE 'Base de datos inicializada correctamente con tablas, índices, funciones y datos de ejemplo.';
    RAISE NOTICE 'Datos cargados:';
    RAISE NOTICE '  - 1 provincia (Córdoba)';
    RAISE NOTICE '  - 26 departamentos';
    RAISE NOTICE '  - 14 regiones sanitarias';
    RAISE NOTICE '  - 56 localidades';
    RAISE NOTICE '  - 26 registros de datos censales';
    RAISE NOTICE '  - 50+ indicadores de adicciones';
END $$;
