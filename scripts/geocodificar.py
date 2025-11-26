#!/usr/bin/env python3
"""
Geocodificador de localidades de Córdoba.

Este script permite geocodificar localidades de la provincia de Córdoba, Argentina,
utilizando una base de datos local de coordenadas y, opcionalmente, el servicio
de Nominatim (OpenStreetMap) para localidades no encontradas localmente.

Uso:
    python geocodificar.py --input datos.csv --columna localidad --output datos_geo.csv

Ejemplos:
    # Geocodificar archivo CSV con columna 'localidad'
    python geocodificar.py --input pacientes.csv --columna localidad --output pacientes_geo.csv
    
    # Usar solo base de datos local (sin consultas a Nominatim)
    python geocodificar.py --input datos.csv --columna ciudad --output datos_geo.csv --solo-local
    
    # Especificar delimitador diferente
    python geocodificar.py --input datos.csv --columna localidad --output datos_geo.csv --delimitador ";"

Autor: Sistema de Indicadores de Adicciones - Córdoba
Licencia: GPL-3.0
"""

import argparse
import csv
import sys
import time
import unicodedata

# Base de datos local de localidades de Córdoba con coordenadas
# Las coordenadas son aproximadas del centro de cada localidad
LOCALIDADES_CORDOBA = {
    # Ciudades principales
    "cordoba": (-31.4201, -64.1888),
    "rio cuarto": (-33.1307, -64.3499),
    "villa maria": (-32.4074, -63.2429),
    "san francisco": (-31.4281, -62.0828),
    "carlos paz": (-31.4241, -64.4979),
    "villa carlos paz": (-31.4241, -64.4979),
    "alta gracia": (-31.6596, -64.4298),
    "rio tercero": (-32.1737, -64.1144),
    "jesus maria": (-30.9816, -64.0953),
    "bell ville": (-32.6277, -62.6889),
    "cruz del eje": (-30.7269, -64.8063),
    "marcos juarez": (-32.6908, -62.1057),
    "villa del rosario": (-31.5607, -63.5349),
    "cosquin": (-31.2436, -64.4664),
    "dean funes": (-30.4268, -64.3507),
    "la carlota": (-33.4178, -63.2967),
    "villa dolores": (-31.9442, -65.1890),
    "la calera": (-31.3439, -64.3347),
    "santa rosa de calamuchita": (-32.0669, -64.5364),
    "laboulaye": (-34.1269, -63.3911),
    "villa huidobro": (-34.8389, -64.5833),
    
    # Localidades medianas
    "santa rosa de rio primero": (-31.1530, -63.4075),
    "villa del totoral": (-30.8142, -64.0031),
    "villa cura brochero": (-31.7064, -65.0186),
    "villa tulumba": (-30.3994, -64.1269),
    "san francisco del chanar": (-29.7881, -63.9442),
    "villa de maria": (-29.8983, -63.7178),
    "salsacate": (-31.3167, -65.0833),
    "san carlos minas": (-31.1750, -65.0917),
    "la falda": (-31.0905, -64.4930),
    "villa giardino": (-31.0397, -64.5006),
    "huerta grande": (-31.0716, -64.4903),
    "unquillo": (-31.2308, -64.3142),
    "rio ceballos": (-31.1656, -64.3239),
    "saldan": (-31.3069, -64.3142),
    "villa allende": (-31.2936, -64.2958),
    "mendiolaza": (-31.2592, -64.3003),
    "almafuerte": (-32.1919, -64.2492),
    "embalse": (-32.1833, -64.4167),
    "pilar": (-31.6756, -63.8825),
    "morteros": (-30.7139, -62.0044),
    "brinkmann": (-30.8661, -62.0389),
    "portena": (-31.0133, -62.0686),
    "general baldissera": (-33.1200, -62.3000),
    "justiniano posse": (-32.8833, -62.6833),
    "canals": (-33.5633, -62.8861),
    "general cabrera": (-32.8192, -63.8756),
    "general deheza": (-32.7544, -63.7900),
    "villa general belgrano": (-31.9792, -64.5564),
    "los reartes": (-31.9061, -64.5856),
    "villa de soto": (-30.8558, -64.9942),
    "villa nueva": (-32.4333, -63.2500),
    "laguna larga": (-31.7817, -63.7967),
    "quilino": (-30.2167, -64.5000),
    "san javier": (-31.9833, -65.0500),
    "yacanto": (-32.0333, -65.1000),
    
    # Otras localidades
    "mina clavero": (-31.7217, -65.0050),
    "nono": (-31.7833, -65.0167),
    "las varillas": (-31.8667, -62.7167),
    "oncativo": (-31.9167, -63.6833),
    "monte cristo": (-31.3500, -63.9500),
    "villa allende": (-31.2944, -64.2958),
    "corral de bustos": (-33.2833, -62.1833),
    "oliva": (-32.0333, -63.5667),
    "capilla del monte": (-30.8569, -64.5264),
    "san jose de la dormida": (-30.3500, -63.9500),
    "arroyito": (-31.4167, -63.0500),
    "las perdices": (-32.7000, -63.7000),
    "devoto": (-31.4000, -62.3000),
    "adelia maria": (-33.6333, -64.0167),
    "coronel moldes": (-33.6167, -64.6000),
    "sampacho": (-33.3833, -64.7167),
    "alcira": (-34.0333, -64.3833),
    "vicuna mackenna": (-33.9167, -64.3833),
    "huinca renanco": (-34.8333, -64.3667),
    "mattaldi": (-34.4833, -64.2000),
}


def normalizar_texto(texto):
    """
    Normaliza el texto para facilitar la búsqueda.
    Remueve acentos, convierte a minúsculas y elimina espacios extras.
    Preserva la letra 'ñ' ya que es distintiva en español.
    
    Args:
        texto: Texto a normalizar
        
    Returns:
        Texto normalizado
    """
    if not texto:
        return ""
    
    # Convertir a minúsculas
    texto = texto.lower().strip()
    
    # Preservar la ñ antes de la normalización
    texto = texto.replace("ñ", "\x00")  # Marcador temporal
    
    # Remover acentos usando normalización Unicode
    texto = unicodedata.normalize('NFD', texto)
    texto = ''.join(char for char in texto if unicodedata.category(char) != 'Mn')
    
    # Restaurar la ñ
    texto = texto.replace("\x00", "n")  # Convertir a n para facilitar búsqueda
    
    return texto


def geocodificar_local(nombre):
    """
    Busca las coordenadas de una localidad en la base de datos local.
    
    Args:
        nombre: Nombre de la localidad a buscar
        
    Returns:
        Tupla (latitud, longitud) o (None, None) si no se encuentra
    """
    nombre_normalizado = normalizar_texto(nombre)
    return LOCALIDADES_CORDOBA.get(nombre_normalizado, (None, None))


def geocodificar_nominatim(direccion, provincia="Córdoba"):
    """
    Geocodifica una dirección usando el servicio de Nominatim (OpenStreetMap).
    
    IMPORTANTE: Este servicio tiene límites de uso. No usar para más de 1 solicitud
    por segundo y respetar los términos de uso de OpenStreetMap.
    
    Args:
        direccion: Dirección o nombre de localidad a geocodificar
        provincia: Nombre de la provincia (por defecto "Córdoba")
        
    Returns:
        Tupla (latitud, longitud) o (None, None) si no se encuentra
    """
    try:
        import requests
    except ImportError:
        print("Error: El módulo 'requests' no está instalado.")
        print("Instálelo con: pip install requests")
        return None, None
    
    url = "https://nominatim.openstreetmap.org/search"
    params = {
        "q": f"{direccion}, {provincia}, Argentina",
        "format": "json",
        "limit": 1
    }
    headers = {
        "User-Agent": "IndicadoresAdiccionesCordoba/1.0 (https://github.com/fran1599/mapa-indicadores)"
    }
    
    try:
        response = requests.get(url, params=params, headers=headers, timeout=10)
        response.raise_for_status()
        
        resultados = response.json()
        if resultados:
            resultado = resultados[0]
            return float(resultado["lat"]), float(resultado["lon"])
    except requests.exceptions.RequestException as e:
        print(f"Error de conexión geocodificando '{direccion}': {e}")
    except (KeyError, ValueError, IndexError) as e:
        print(f"Error procesando respuesta para '{direccion}': {e}")
    
    return None, None


def geocodificar(nombre, usar_nominatim=True):
    """
    Geocodifica una localidad, primero buscando localmente y luego en Nominatim.
    
    Args:
        nombre: Nombre de la localidad
        usar_nominatim: Si True, usa Nominatim si no se encuentra localmente
        
    Returns:
        Tupla (latitud, longitud, fuente) donde fuente es 'local' o 'nominatim'
    """
    # Primero buscar en base de datos local
    lat, lon = geocodificar_local(nombre)
    if lat is not None:
        return lat, lon, "local"
    
    # Si no se encuentra y está habilitado, buscar en Nominatim
    if usar_nominatim:
        lat, lon = geocodificar_nominatim(nombre)
        if lat is not None:
            return lat, lon, "nominatim"
    
    return None, None, None


def procesar_csv(archivo_entrada, columna_localidad, archivo_salida, 
                 solo_local=False, delimitador=','):
    """
    Procesa un archivo CSV y agrega columnas de latitud y longitud.
    
    Args:
        archivo_entrada: Ruta al archivo CSV de entrada
        columna_localidad: Nombre de la columna con las localidades
        archivo_salida: Ruta al archivo CSV de salida
        solo_local: Si True, solo usa la base de datos local
        delimitador: Delimitador del archivo CSV
    """
    estadisticas = {
        "total": 0,
        "geocodificados_local": 0,
        "geocodificados_nominatim": 0,
        "no_encontrados": 0
    }
    
    try:
        with open(archivo_entrada, 'r', encoding='utf-8') as f_entrada:
            lector = csv.DictReader(f_entrada, delimiter=delimitador)
            
            if columna_localidad not in lector.fieldnames:
                print(f"Error: La columna '{columna_localidad}' no existe en el archivo.")
                print(f"Columnas disponibles: {', '.join(lector.fieldnames)}")
                return False
            
            # Preparar campos de salida
            campos_salida = lector.fieldnames + ['latitud', 'longitud', 'fuente_geocodificacion']
            
            with open(archivo_salida, 'w', encoding='utf-8', newline='') as f_salida:
                escritor = csv.DictWriter(f_salida, fieldnames=campos_salida, delimiter=delimitador)
                escritor.writeheader()
                
                for fila in lector:
                    estadisticas["total"] += 1
                    localidad = fila.get(columna_localidad, "")
                    
                    lat, lon, fuente = geocodificar(localidad, usar_nominatim=not solo_local)
                    
                    fila['latitud'] = lat if lat else ""
                    fila['longitud'] = lon if lon else ""
                    fila['fuente_geocodificacion'] = fuente if fuente else "no_encontrado"
                    
                    if fuente == "local":
                        estadisticas["geocodificados_local"] += 1
                    elif fuente == "nominatim":
                        estadisticas["geocodificados_nominatim"] += 1
                        # Respetar límite de Nominatim
                        time.sleep(1)
                    else:
                        estadisticas["no_encontrados"] += 1
                        print(f"  Advertencia: No se encontró '{localidad}'")
                    
                    escritor.writerow(fila)
                    
                    # Mostrar progreso cada 10 registros
                    if estadisticas["total"] % 10 == 0:
                        print(f"  Procesados: {estadisticas['total']} registros...")
        
        # Mostrar resumen
        print("\n" + "=" * 50)
        print("RESUMEN DE GEOCODIFICACIÓN")
        print("=" * 50)
        print(f"Total de registros:           {estadisticas['total']}")
        print(f"Geocodificados (local):       {estadisticas['geocodificados_local']}")
        print(f"Geocodificados (Nominatim):   {estadisticas['geocodificados_nominatim']}")
        print(f"No encontrados:               {estadisticas['no_encontrados']}")
        
        porcentaje = ((estadisticas['geocodificados_local'] + estadisticas['geocodificados_nominatim']) 
                     / estadisticas['total'] * 100) if estadisticas['total'] > 0 else 0
        print(f"Tasa de éxito:                {porcentaje:.1f}%")
        print("=" * 50)
        
        return True
        
    except FileNotFoundError:
        print(f"Error: No se encontró el archivo '{archivo_entrada}'")
        return False
    except PermissionError:
        print(f"Error: No se tienen permisos para leer/escribir los archivos")
        return False
    except csv.Error as e:
        print(f"Error procesando CSV: {e}")
        return False


def main():
    """Función principal del script."""
    parser = argparse.ArgumentParser(
        description="Geocodificar localidades de Córdoba en un archivo CSV",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  %(prog)s --input datos.csv --columna localidad --output datos_geo.csv
  %(prog)s --input pacientes.csv --columna ciudad --output pacientes_geo.csv --solo-local
  %(prog)s --input datos.csv --columna localidad --output datos_geo.csv --delimitador ";"
  %(prog)s --listar-localidades
        """
    )
    
    parser.add_argument(
        "--input", "-i",
        help="Archivo CSV de entrada"
    )
    
    parser.add_argument(
        "--columna", "-c",
        default="localidad",
        help="Nombre de la columna con las localidades (por defecto: 'localidad')"
    )
    
    parser.add_argument(
        "--output", "-o",
        help="Archivo CSV de salida"
    )
    
    parser.add_argument(
        "--solo-local",
        action="store_true",
        help="Usar solo la base de datos local (no consultar Nominatim)"
    )
    
    parser.add_argument(
        "--delimitador", "-d",
        default=",",
        help="Delimitador del archivo CSV (por defecto: ',')"
    )
    
    parser.add_argument(
        "--listar-localidades",
        action="store_true",
        help="Listar todas las localidades disponibles en la base de datos local"
    )
    
    args = parser.parse_args()
    
    # Opción para listar localidades disponibles
    if args.listar_localidades:
        print("Localidades disponibles en la base de datos local:")
        print("-" * 50)
        for localidad in sorted(LOCALIDADES_CORDOBA.keys()):
            lat, lon = LOCALIDADES_CORDOBA[localidad]
            print(f"  {localidad.title()}: ({lat}, {lon})")
        print(f"\nTotal: {len(LOCALIDADES_CORDOBA)} localidades")
        return 0
    
    # Verificar que se proporcionaron los argumentos requeridos para geocodificación
    if not args.input or not args.output:
        parser.error("Los argumentos --input y --output son requeridos para geocodificar")
    
    print(f"Geocodificando archivo: {args.input}")
    print(f"Columna de localidades: {args.columna}")
    print(f"Archivo de salida: {args.output}")
    print(f"Modo: {'Solo local' if args.solo_local else 'Local + Nominatim'}")
    print("-" * 50)
    
    exito = procesar_csv(
        args.input,
        args.columna,
        args.output,
        solo_local=args.solo_local,
        delimitador=args.delimitador
    )
    
    return 0 if exito else 1


if __name__ == "__main__":
    sys.exit(main())
