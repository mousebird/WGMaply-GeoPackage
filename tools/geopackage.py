#!/usr/bin/env python
#
#
#  geopackage.py
#  MBTiles to GeoPackage conversor
#
#  Created by jmnavarro
#  Copyright © 2017 mousebird consulting. All rights reserved.
#
import sys
import argparse, logging
import sqlite3
import math
import os
from pathlib import Path


def main(source_file, target_file):
    logging.info("Converting '%s' in '%s'..." % (source_file, target_file))

    #
    # source
    #
    if not Path(source_file).is_file():
        logging.error("Source file \"%s\" does not exist" % source_file)
        return

    logging.debug("Opening source \"%s\" sqlite file..." % source_file)
    source_conn = sqlite3.connect(source_file)
    logging.debug("Source sqlite file opened")

    logging.debug("Checking mbtiles format...")
    if not check_mbtiles(source_conn):
        logging.error("MBTiles file seems to be invalid")
        source_conn.close()
        return

    #
    # target
    #
    exists = Path(target_file).is_file()

    if exists:
        logging.debug("Removing file '%s'..." % target_file)
        os.remove(target_file)

    logging.debug("Opening target \"%s\" sqlite file..." % target_file)
    target_conn = sqlite3.connect(target_file)
    logging.debug("Target sqlite file opened")

    if not create_geopackage_tables(target_conn):
        logging.error("GeoPackage tables can't be created")
        source_conn.close()
        target_conn.close()
        return
    else:
        logging.debug("GeoPackage tables created")

    min_zoom, max_zoom = get_zoom_level(source_conn)
    spherical_mercator_bounds = get_spherical_mercator(source_conn)

    #
    # Fill target
    #
    logging.debug("Filling gpkg_spatial_ref_sys...")
    fill_spatial_ref_sys(target_conn)

    logging.debug("Filling gpkg_contents...")
    fill_contents(target_conn, spherical_mercator_bounds)

    logging.debug("Filling gpkg_tile_matrix_set...")
    fill_tile_matrix_set(target_conn, spherical_mercator_bounds)

    logging.debug("Filling gpkg_tile_matrix...")
    fill_tile_matrix(target_conn, min_zoom, max_zoom, spherical_mercator_bounds)

    logging.debug("Filling tiles table...")
    fill_tiles_table(source_conn, target_conn)

    source_conn.close()
    target_conn.close()

    logging.info("Done!")


def lonlat_to_mercator(lon, lat):
    rMajor = 6378137
    shift = math.pi * rMajor
    x = float(lon) * shift / 180
    x = float(lon) * 20037508.34 / 180
    y = math.log(math.tan((90 + float(lat)) * math.pi / 360)) / (math.pi / 180)
    y = y * shift / 180
    return [x, y]


def get_spherical_mercator(source):
    logging.debug("Getting source min_x, min_y, max_x, max_y ...")
    mb_metadata = dict(source.execute('select name, value from metadata').fetchall())
    bounds = mb_metadata['bounds'].split(",")
    minxy = lonlat_to_mercator(bounds[0], bounds[1])
    maxxy = lonlat_to_mercator(bounds[2], bounds[3])
    spherical_mercator_bounds = [minxy[0], minxy[1], maxxy[0], maxxy[1]]
    return spherical_mercator_bounds


def get_zoom_level(conn):
    logging.debug("Getting source zoom level...")
    cursor = conn.execute("SELECT min(zoom_level), max(zoom_level) FROM tiles")
    result = cursor.fetchone()
    logging.debug("Min/max zoom level is %d/%d" % result)
    return result


def fill_spatial_ref_sys(conn):
    cursor = conn.execute("SELECT count(*) FROM gpkg_spatial_ref_sys")
    result = cursor.fetchone()
    if len(result or ()) > 0 and result[0] > 0:
        logging.debug("Don't add new content to 'gpkg_spatial_ref_sys'")
        return

    values = [
        ('Undefined cartesian SRS', -1, 'NONE', -1, 'undefined', 'undefined cartesian coordinate reference system'),
        ('Undefined geographic SRS', 0, 'NONE', 0, 'undefined', 'undefined geographic coordinate reference system'),
        ('WGS 84 / Pseudo-Mercator', 3857, 'EPSG', 3857,
         "PROJCS[\"WGS 84 / Pseudo-Mercator\",GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.0174532925199433,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4326\"]],PROJECTION[\"Mercator_1SP\"],PARAMETER[\"central_meridian\",0],PARAMETER[\"scale_factor\",1],PARAMETER[\"false_easting\",0],PARAMETER[\"false_northing\",0],UNIT[\"metre\",1,AUTHORITY[\"EPSG\",\"9001\"]],AXIS[\"X\",EAST],AXIS[\"Y\",NORTH],EXTENSION[\"PROJ4\",\"+proj=merc +a=6378137 +b=6378137 +lat_ts=0.0 +lon_0=0.0 +x_0=0.0 +y_0=0 +k=1.0 +units=m +nadgrids=@null +wktext  +no_defs\"],AUTHORITY[\"EPSG\",\"3857\"]]",
         'Spherical Mercator projection coordinate system'),
        ('WGS 84 geodetic', 4326, 'EPSG', 4326,
         "GEOGCS[\"WGS 84\",DATUM[\"WGS_1984\",SPHEROID[\"WGS 84\",6378137,298.257223563,AUTHORITY[\"EPSG\",\"7030\"]],AUTHORITY[\"EPSG\",\"6326\"]],PRIMEM[\"Greenwich\",0,AUTHORITY[\"EPSG\",\"8901\"]],UNIT[\"degree\",0.01745329251994328,AUTHORITY[\"EPSG\",\"9122\"]],AUTHORITY[\"EPSG\",\"4326\"]]",
         'longitude/latitude coordinates in decimal degrees on the WGS 84 spheroid'),
    ]
    conn.executemany('INSERT INTO gpkg_spatial_ref_sys VALUES (?,?,?,?,?,?)', values)
    logging.debug("Added content to 'gpkg_spatial_ref_sys")
    conn.commit()


def fill_contents(conn, spherical_mercator_bounds):
    cursor = conn.execute("SELECT count(*) FROM gpkg_contents WHERE identifier='%s'" % 'tiles')
    result = cursor.fetchone()
    if len(result or ()) > 0 and result[0] > 0:
        date_format = '%Y-%m-%dT%H:%M:%fZ'
        conn.execute(
            "UPDATE gpkg_contents SET last_change=strftime('%s','now'), min_x = %d , min_y = %d, max_x = %d, max_y = %d  WHERE identifier='%s'" % (
                date_format, spherical_mercator_bounds[0], spherical_mercator_bounds[1], spherical_mercator_bounds[2],
                spherical_mercator_bounds[3], 'tiles'))
        logging.debug("Updated record to 'gpkg_contents'")
    else:
        values = [
            ('tiles', 'tiles', 'tiles', 3857, spherical_mercator_bounds[0], spherical_mercator_bounds[1],
             spherical_mercator_bounds[2], spherical_mercator_bounds[3]),
        ]
        conn.executemany(
            'INSERT INTO gpkg_contents(table_name, data_type, identifier, srs_id, min_x, min_y, max_x, max_y) VALUES (?,?,?,?,?,?,?,?)',
            values)
        logging.debug("Added new record to 'gpkg_contents'")

    conn.commit()


def fill_tile_matrix_set(conn, spherical_mercator_bounds):
    cursor = conn.execute("SELECT count(*) FROM gpkg_tile_matrix_set WHERE table_name='tiles'")
    result = cursor.fetchone()
    if len(result or ()) > 0 and result[0] > 0:
        conn.execute(
            "UPDATE gpkg_tile_matrix_set SET min_x = %d , min_y = %d, max_x = %d, max_y = %d WHERE table_name='tiles'" % (
                spherical_mercator_bounds[0], spherical_mercator_bounds[1], spherical_mercator_bounds[2],
                spherical_mercator_bounds[3]))
        logging.debug("Updated record to 'gpkg_tile_matrix_set' for table 'tiles'")
    else:
        values = [
            ("tiles", 3857, spherical_mercator_bounds[0], spherical_mercator_bounds[1], spherical_mercator_bounds[2],
             spherical_mercator_bounds[3]),
        ]
        conn.executemany(
            'INSERT INTO gpkg_tile_matrix_set(table_name, srs_id, min_x, min_y, max_x, max_y) VALUES (?,?,?,?,?,?)',
            values)
        logging.debug("Added new record to 'gpkg_tile_matrix_set'")

    conn.commit()


def size(spherical_mercator_bounds):
    return ((spherical_mercator_bounds[2] - spherical_mercator_bounds[0]),
            (spherical_mercator_bounds[3] - spherical_mercator_bounds[1]))


def fill_tile_matrix(conn, min_zoom, max_zoom, spherical_mercator_bounds):
    for z in range(min_zoom, max_zoom + 1):
        cursor = conn.execute(
            "SELECT count(*) FROM gpkg_tile_matrix WHERE table_name='tiles' and zoom_level=%d" % z)
        result = cursor.fetchone()
        cols = (2 ** z)
        rows = cols
        sizePixel = size(spherical_mercator_bounds)
        if len(result or ()) > 0 and result[0] > 0:
            conn.execute("UPDATE gpkg_tile_matrix SET pixel_x_size = %s, pixel_y_size = %s WHERE zoom_level=%d" % (
                sizePixel[0] / (256 * cols), sizePixel[1] / (256 * rows), z))
            logging.debug("Updated record to 'gpkg_tile_matrix' for table 'tiles' and zoom_level=%d" % z)
        else:
            values = [
                ("tiles", z, 2 ** z, 2 ** z, 256, 256, sizePixel[0] / (256 * cols), sizePixel[1] / (256 * rows)),
            ]
            conn.executemany(
                'INSERT INTO gpkg_tile_matrix(table_name, zoom_level, matrix_width, matrix_height, tile_width, tile_height,pixel_x_size, pixel_y_size) VALUES (?,?,?,?,?,?,?,?)',
                values)
            logging.debug("Added new record to 'gpkg_tile_matrix' for zoom_level=%d" % z)

        conn.commit()


def fill_tiles_table(source, conn):
    cursor = source.execute("SELECT zoom_level, tile_column, tile_row, tile_data FROM tiles ORDER BY zoom_level")
    tiles = cursor.fetchall()
    values = []
    for data in tiles:
        third = flip_y(data[0], data[2])
        values.append((data[0], data[1], third, memoryview(data[3])))

    conn.executemany("INSERT OR REPLACE INTO tiles (zoom_level, tile_column, tile_row, tile_data) VALUES (?,?,?,?)",
                     values)
    conn.commit()


def flip_y(zoom, y):
    return (2 ** zoom - 1) - y


def create_views(conn):
    conn.execute(
        "CREATE VIEW spatial_ref_sys AS SELECT srs_id AS srid, organization AS auth_name, organization_coordsys_id AS auth_srid, definition AS srtext FROM gpkg_spatial_ref_sys")
    conn.execute(
        "CREATE VIEW st_spatial_ref_sys AS SELECT srs_name, srs_id, organization, organization_coordsys_id, definition, description FROM gpkg_spatial_ref_sys")


def create_triggers(conn):
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_matrix_height_insert'BEFORE INSERT ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'insert on table ''gpkg_tile_matrix'' violates constraint: matrix_height cannot be less than 1')WHERE (NEW.matrix_height < 1);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_matrix_height_update'BEFORE UPDATE OF matrix_height ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'update on table ''gpkg_tile_matrix'' violates constraint: matrix_height cannot be less than 1')WHERE (NEW.matrix_height < 1);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_matrix_width_insert'BEFORE INSERT ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'insert on table ''gpkg_tile_matrix'' violates constraint: matrix_width cannot be less than 1')WHERE (NEW.matrix_width < 1);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_matrix_width_update'BEFORE UPDATE OF matrix_width ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'update on table ''gpkg_tile_matrix'' violates constraint: matrix_width cannot be less than 1')WHERE (NEW.matrix_width < 1);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_pixel_x_size_insert'BEFORE INSERT ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'insert on table ''gpkg_tile_matrix'' violates constraint: pixel_x_size must be greater than 0')WHERE NOT (NEW.pixel_x_size > 0);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_pixel_x_size_update'BEFORE UPDATE OF pixel_x_size ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'update on table ''gpkg_tile_matrix'' violates constraint: pixel_x_size must be greater than 0')WHERE NOT (NEW.pixel_x_size > 0);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_pixel_y_size_insert'BEFORE INSERT ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'insert on table ''gpkg_tile_matrix'' violates constraint: pixel_y_size must be greater than 0')WHERE NOT (NEW.pixel_y_size > 0);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_pixel_y_size_update'BEFORE UPDATE OF pixel_y_size ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'update on table ''gpkg_tile_matrix'' violates constraint: pixel_y_size must be greater than 0')WHERE NOT (NEW.pixel_y_size > 0);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_zoom_level_insert'BEFORE INSERT ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'insert on table ''gpkg_tile_matrix'' violates constraint: zoom_level cannot be less than 0')WHERE (NEW.zoom_level < 0);END")
    conn.execute(
        "CREATE TRIGGER 'gpkg_tile_matrix_zoom_level_update'BEFORE UPDATE of zoom_level ON 'gpkg_tile_matrix'FOR EACH ROW BEGIN SELECT RAISE(ABORT, 'update on table ''gpkg_tile_matrix'' violates constraint: zoom_level cannot be less than 0')WHERE (NEW.zoom_level < 0);END")


def create_geopackage_tables(conn):
    def exists_table(conn, table_name):
        cursor = conn.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='%s'" % table_name)
        result = cursor.fetchone()
        return len(result or ()) == 1

    valid = True
    try:
        if not exists_table(conn, 'gpkg_spatial_ref_sys'):
            logging.debug("Creating table '%s'..." % "gpkg_spatial_ref_sys")
            conn.execute(
                "CREATE TABLE gpkg_spatial_ref_sys ( srs_name TEXT NOT NULL, srs_id INTEGER NOT NULL PRIMARY KEY, organization TEXT NOT NULL, organization_coordsys_id INTEGER NOT NULL, definition TEXT NOT NULL, description TEXT )")

        if not exists_table(conn, 'gpkg_contents'):
            logging.debug("Creating table '%s'..." % "gpkg_contents")
            conn.execute(
                "CREATE TABLE gpkg_contents ( table_name TEXT NOT NULL PRIMARY KEY, data_type TEXT NOT NULL, identifier TEXT UNIQUE, description TEXT DEFAULT '', last_change DATETIME NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')), min_x DOUBLE, min_y DOUBLE, max_x DOUBLE, max_y DOUBLE, srs_id INTEGER, CONSTRAINT fk_gc_r_srs_id FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys(srs_id) )")

        if not exists_table(conn, 'gpkg_tile_matrix'):
            logging.debug("Creating table '%s'..." % "gpkg_tile_matrix")
            conn.execute(
                "CREATE TABLE gpkg_tile_matrix ( table_name TEXT NOT NULL, zoom_level INTEGER NOT NULL, matrix_width INTEGER NOT NULL, matrix_height INTEGER NOT NULL, tile_width INTEGER NOT NULL, tile_height INTEGER NOT NULL, pixel_x_size DOUBLE NOT NULL, pixel_y_size DOUBLE NOT NULL, CONSTRAINT pk_ttm PRIMARY KEY (table_name, zoom_level), CONSTRAINT fk_tmm_table_name FOREIGN KEY (table_name) REFERENCES gpkg_contents(table_name) )")

        if not exists_table(conn, 'gpkg_tile_matrix_set'):
            logging.debug("Creating table '%s'..." % "gpkg_tile_matrix_set")
            conn.execute(
                "CREATE TABLE gpkg_tile_matrix_set ( table_name TEXT NOT NULL PRIMARY KEY, srs_id INTEGER NOT NULL, min_x DOUBLE NOT NULL, min_y DOUBLE NOT NULL, max_x DOUBLE NOT NULL, max_y DOUBLE NOT NULL, CONSTRAINT fk_gtms_table_name FOREIGN KEY (table_name) REFERENCES gpkg_contents(table_name), CONSTRAINT fk_gtms_srs FOREIGN KEY (srs_id) REFERENCES gpkg_spatial_ref_sys (srs_id) )")

            #       if not exists_table(conn, 'gpkg_extensions'):
            #           logging.debug("Creating table '%s'..." % "gpkg_extensions")
            #           conn.execute(
            #               "CREATE TABLE gpkg_extensions ( table_name TEXT, column_name TEXT, extension_name TEXT NOT NULL, definition TEXT NOT NULL, scope TEXT NOT NULL, CONSTRAINT ge_tce UNIQUE (table_name, column_name, extension_name) )")

        table_name = 'tiles'
        if not exists_table(conn, table_name):
            logging.debug("Creating table '%s'..." % table_name)
            conn.execute(
                "CREATE TABLE %s ( id INTEGER PRIMARY KEY AUTOINCREMENT, zoom_level INTEGER NOT NULL, tile_column INTEGER NOT NULL, tile_row INTEGER NOT NULL, tile_data BLOB NOT NULL, UNIQUE (zoom_level, tile_column, tile_row) )" % table_name)

    except sqlite3.OperationalError as e:
        logging.error("Error creating GeoPackage tables: %s" % e)
        valid = False

    create_triggers(conn)
    create_views(conn)

    return valid


def check_mbtiles(conn):
    def check_table(conn, table_name):
        logging.debug("Checking table '%s'..." % table_name)
        cursor = conn.execute('SELECT count(*) FROM %s' % table_name)
        result = cursor.fetchone()
        if len(result or ()) == 0 or result[0] <= 0:
            logging.error("Error checking '%s' table" % table_name)
            return False
        else:
            logging.debug("Table '%s' has %d records" % (table_name, result[0]))
            return True

    valid = True

    try:
        valid = valid and check_table(conn, "metadata")
        valid = check_table(conn, "tiles")
    except sqlite3.OperationalError as e:
        logging.error("Error checking MBTiles: %s" % e)
        valid = False

    return valid


def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Converts MBTiles file to GeoPackage format, suitable to be used in WhirlyGlobe toolkit.",
        epilog="As an alternative to the commandline, params can be placed in a file, one per line, and specified on the commandline like '%(prog)s @params.conf'.",
        fromfile_prefix_chars='@')

    parser.add_argument(
        "mbtiles",
        help="MBTiles source file.",
        metavar="mbtiles")
    parser.add_argument(
        "geopackage",
        help="GeoPackage target file.",
        metavar="geopackage")
    parser.add_argument(
        "-v",
        "--verbose",
        help="increase output verbosity",
        action="store_true")

    return parser.parse_args()


def prepare_logger(args):
    if args.verbose:
        loglevel = logging.DEBUG
    else:
        loglevel = logging.INFO
    logging.basicConfig(format="%(levelname)s: %(message)s", level=loglevel)


if __name__ == '__main__':
    args = parse_arguments()

    prepare_logger(args)

    main(args.mbtiles, args.geopackage)
