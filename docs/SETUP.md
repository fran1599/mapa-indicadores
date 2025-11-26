# Guía de Instalación Detallada

Esta guía proporciona instrucciones completas para instalar y configurar el sistema de visualización de indicadores de adicciones para la Provincia de Córdoba.

## Requisitos del Sistema

### Hardware Mínimo
- **CPU**: 2 núcleos
- **RAM**: 4 GB (8 GB recomendado)
- **Almacenamiento**: 10 GB de espacio libre
- **Red**: Conexión a Internet para descargar imágenes Docker

### Software Requerido
- Sistema operativo: Linux, macOS o Windows 10/11
- Docker Engine 20.10 o superior
- Docker Compose 2.0 o superior
- Git (para clonar el repositorio)
- Python 3.8+ (opcional, para geocodificación)

## Instalación de Docker

### Linux (Ubuntu/Debian)

```bash
# Actualizar paquetes
sudo apt update

# Instalar dependencias
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Agregar clave GPG de Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Agregar repositorio de Docker
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Instalar Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Agregar usuario al grupo docker (para evitar usar sudo)
sudo usermod -aG docker $USER

# Aplicar cambios (o reiniciar sesión)
newgrp docker

# Verificar instalación
docker --version
docker compose version
```

### macOS

1. Descargar [Docker Desktop para Mac](https://www.docker.com/products/docker-desktop)
2. Abrir el archivo `.dmg` e instalar
3. Iniciar Docker Desktop desde Aplicaciones
4. Verificar en terminal:
   ```bash
   docker --version
   docker compose version
   ```

### Windows 10/11

1. Habilitar WSL 2:
   ```powershell
   wsl --install
   ```
2. Descargar [Docker Desktop para Windows](https://www.docker.com/products/docker-desktop)
3. Ejecutar el instalador y seguir las instrucciones
4. Reiniciar el sistema si es necesario
5. Iniciar Docker Desktop
6. Verificar en PowerShell:
   ```powershell
   docker --version
   docker compose version
   ```

## Configuración Inicial

### 1. Clonar el Repositorio

```bash
git clone https://github.com/tu-usuario/mapa-indicadores.git
cd mapa-indicadores
```

### 2. Configurar Variables de Entorno

```bash
# Copiar archivo de ejemplo
cp .env.example .env

# Editar configuración (opcional)
nano .env  # o usar tu editor preferido
```

Variables disponibles:

| Variable | Descripción | Valor por defecto |
|----------|-------------|-------------------|
| POSTGRES_DB | Nombre de la base de datos | gis_adicciones |
| POSTGRES_USER | Usuario de PostgreSQL | gisuser |
| POSTGRES_PASSWORD | Contraseña de PostgreSQL | gispassword |
| GEOSERVER_ADMIN_PASSWORD | Contraseña de admin de GeoServer | admin123 |
| PGADMIN_DEFAULT_EMAIL | Email de admin de pgAdmin | admin@local.dev |
| PGADMIN_DEFAULT_PASSWORD | Contraseña de pgAdmin | admin123 |

### 3. Iniciar los Servicios

```bash
# Iniciar en modo detached (segundo plano)
docker-compose up -d

# Ver progreso de descarga de imágenes
docker-compose logs -f
```

La primera vez tardará varios minutos mientras se descargan las imágenes Docker.

### 4. Verificar Estado

```bash
# Ver estado de contenedores
docker-compose ps

# Resultado esperado:
# NAME            STATUS                   PORTS
# gis_postgis     Up (healthy)             0.0.0.0:5432->5432/tcp
# gis_geoserver   Up                       0.0.0.0:8080->8080/tcp
# gis_kepler      Up                       0.0.0.0:8081->80/tcp
# gis_pgadmin     Up                       0.0.0.0:5050->80/tcp
```

### 5. Cargar Datos de Córdoba

```bash
# Dar permisos de ejecución al script
chmod +x scripts/cargar_datos.sh

# Ejecutar carga de datos de Córdoba
./scripts/cargar_datos.sh
```

Este script carga:
- 26 departamentos de Córdoba
- 14 regiones sanitarias
- 55+ localidades con coordenadas
- Datos de ejemplo de indicadores
- Datos censales de muestra

### 6. Cargar Datos de Ejemplo General (Opcional)

```bash
# Dar permisos de ejecución al script
chmod +x scripts/load-sample-data.sh

# Ejecutar carga de datos
./scripts/load-sample-data.sh
```

## Solución de Problemas Comunes

### Error: Puerto en uso

Si ves un error como `port is already allocated`:

```bash
# Identificar qué proceso usa el puerto (ejemplo: 5432)
sudo lsof -i :5432

# Detener el proceso o cambiar el puerto en docker-compose.yml
```

Para cambiar puertos, editar `docker-compose.yml`:
```yaml
ports:
  - "5433:5432"  # Usar puerto 5433 en lugar de 5432
```

### Error: Permisos de Docker

Si ves `permission denied` al ejecutar docker:

```bash
# Linux: agregar usuario al grupo docker
sudo usermod -aG docker $USER
newgrp docker

# O ejecutar con sudo
sudo docker-compose up -d
```

### Error: Memoria insuficiente

Si los contenedores se detienen por falta de memoria:

1. Aumentar memoria disponible para Docker
   - **Docker Desktop**: Settings > Resources > Memory
   - **Linux**: Aumentar RAM o configurar swap

2. Reducir recursos de GeoServer en `docker-compose.yml`:
   ```yaml
   geoserver:
     environment:
       INITIAL_MEMORY: 512m
       MAXIMUM_MEMORY: 1g
   ```

### PostGIS no inicia correctamente

```bash
# Ver logs del contenedor
docker-compose logs postgis

# Reiniciar contenedor
docker-compose restart postgis

# Si persiste, recrear volumen (ADVERTENCIA: borra datos)
docker-compose down -v
docker-compose up -d
```

### GeoServer no se conecta a PostGIS

1. Verificar que PostGIS esté healthy:
   ```bash
   docker-compose ps
   ```

2. Probar conexión manualmente:
   ```bash
   docker exec -it gis_postgis pg_isready -U gisuser -d gis_adicciones
   ```

3. En GeoServer, usar `postgis` como hostname (no `localhost`)

## Personalizar la Configuración

### Cambiar Contraseñas

Antes de usar en producción, cambiar contraseñas en `.env`:

```bash
# Generar contraseñas seguras
openssl rand -base64 32

# Editar .env con nuevas contraseñas
nano .env
```

Luego recrear los contenedores:
```bash
docker-compose down
docker-compose up -d
```

### Agregar más recursos

Para entornos con más datos, ajustar recursos de PostgreSQL creando un archivo `postgresql.conf` personalizado:

```bash
# Crear archivo de configuración
cat > postgres-custom.conf << EOF
shared_buffers = 256MB
work_mem = 64MB
maintenance_work_mem = 128MB
effective_cache_size = 512MB
EOF
```

Y montarlo en `docker-compose.yml`:
```yaml
postgis:
  volumes:
    - ./postgres-custom.conf:/etc/postgresql/postgresql.conf
```

### Configurar HTTPS

Para producción, usar un proxy reverso como Nginx o Traefik:

```yaml
# Agregar en docker-compose.yml
traefik:
  image: traefik:v2.10
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
    - ./traefik:/etc/traefik
```

## Respaldos

### Crear respaldo de PostgreSQL

```bash
# Crear respaldo
docker exec gis_postgis pg_dump -U gisuser gis_adicciones > backup_$(date +%Y%m%d).sql

# Respaldo comprimido
docker exec gis_postgis pg_dump -U gisuser gis_adicciones | gzip > backup_$(date +%Y%m%d).sql.gz
```

### Restaurar respaldo

```bash
# Restaurar desde archivo SQL
cat backup_20240101.sql | docker exec -i gis_postgis psql -U gisuser -d gis_adicciones

# Restaurar desde archivo comprimido
gunzip -c backup_20240101.sql.gz | docker exec -i gis_postgis psql -U gisuser -d gis_adicciones
```

## Actualización del Sistema

### Actualizar imágenes Docker

```bash
# Descargar nuevas versiones
docker-compose pull

# Recrear contenedores con nuevas imágenes
docker-compose up -d
```

### Actualizar esquema de base de datos

Crear scripts de migración en `scripts/migrations/` y ejecutar:

```bash
docker exec -i gis_postgis psql -U gisuser -d gis_adicciones < scripts/migrations/001_nueva_tabla.sql
```

## Siguientes Pasos

Una vez instalado el sistema, continúa con la [Guía de Uso](USO.md) para aprender a:
- Cargar datos geográficos propios
- Crear mapas de calor
- Publicar capas en GeoServer
- Ejecutar consultas espaciales
