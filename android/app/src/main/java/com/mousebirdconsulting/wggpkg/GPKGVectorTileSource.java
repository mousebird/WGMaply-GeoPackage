package com.mousebirdconsulting.wggpkg;

import android.util.Log;

import com.mousebird.maply.CoordSystem;
import com.mousebird.maply.MapboxTileSource;
import com.mousebird.maply.MaplyTileID;
import com.mousebird.maply.Mbr;
import com.mousebird.maply.Point2d;
import com.mousebird.maply.Proj4CoordSystem;

import java.sql.SQLException;
import java.util.HashMap;
import java.util.List;

import mil.nga.geopackage.BoundingBox;
import mil.nga.geopackage.GeoPackage;
import mil.nga.geopackage.core.srs.SpatialReferenceSystem;
import mil.nga.geopackage.core.srs.SpatialReferenceSystemDao;
import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.projection.Projection;
import mil.nga.geopackage.projection.ProjectionRetriever;
import mil.nga.geopackage.tiles.matrix.TileMatrix;
import mil.nga.geopackage.tiles.matrixset.TileMatrixSet;
import mil.nga.geopackage.tiles.retriever.GeoPackageTile;
import mil.nga.geopackage.tiles.retriever.GeoPackageTileRetriever;
import mil.nga.geopackage.tiles.user.TileDao;
import mil.nga.geopackage.tiles.user.TileRow;

/**
 * Implements a vector tile source for MBTile vector format for GeoPackage.
 * Really?  Yup.  Sure.  Why not.
 */
public class GPKGVectorTileSource implements MapboxTileSource {

    TileDao tileDao;
    int minZoom = 0;
    int maxZoom = 0;
    CoordSystem coordSys = null;
    boolean valid = false;
    GeoPackage gpkg;
    HashMap<Integer, Integer[]> tileOffsets = new HashMap<Integer, Integer[]>();
    GeoPackageTileRetriever tileRetrieve;

    public GPKGVectorTileSource(String database, GeoPackage geoPackage, GeoPackageConnection geoPackageConnection,
                                TileDao inTileDao, HashMap<String, List<Number>> bounds) {

        tileDao = inTileDao;
        gpkg = geoPackage;
        SpatialReferenceSystemDao srsDao = geoPackage.getSpatialReferenceSystemDao();
        SpatialReferenceSystem srs;
        try {

            Projection tileDaoProjection = tileDao.getProjection();
            srs = srsDao.getOrCreateCode(
                    tileDaoProjection.getAuthority(),
                    Long.parseLong(tileDaoProjection.getCode()));
            //srs = srsDao.queryForOrganizationCoordsysId(featureDao.getProjection().getEpsg());
        } catch (SQLException e) {
            // TODO: handle error
            return;
        }

        // Note: Should do something with the bounds
        List<Number> srsBounds = bounds.get(String.valueOf(srs.getOrganizationCoordsysId()));
        BoundingBox bbox = new BoundingBox(
                srsBounds.get(0).doubleValue(),
                srsBounds.get(2).doubleValue(),
                srsBounds.get(1).doubleValue(),
                srsBounds.get(3).doubleValue());
        double projMinX = srsBounds.get(4).doubleValue();
        double projMaxY = srsBounds.get(5).doubleValue();

        boolean isDegree = (srsBounds.get(6).intValue() == 1);

        String projStr = ProjectionRetriever.getProjection(srs.getOrganizationCoordsysId());
        coordSys = new Proj4CoordSystem(projStr);
        Mbr mbr = new Mbr();
        mbr.addPoint(new Point2d(bbox.getMinLongitude(), bbox.getMinLatitude()));
        mbr.addPoint(new Point2d(bbox.getMaxLongitude(), bbox.getMaxLatitude()));
        coordSys.setBounds(mbr);

        int n = -1;
        for (int z = (int) tileDao.getMinZoom(); z <= (int) tileDao.getMaxZoom(); z++) {
            TileMatrix tileMatrix = tileDao.getTileMatrix(z);

            if (tileMatrix.getTileWidth() != tileMatrix.getTileHeight()) {
                Log.e("GPKGImageTileSource", "Tile width and height must match.");
                return;
            }

            if (n == -1) {
                n = (int) tileMatrix.getTileWidth();
                if (!(n > 0 && ((n & (n - 1)) == 0))) {
                    Log.e("GPKGImageTileSource", "Tile size must be a positive power of 2.");
                    return;
                }
            } else if (n != tileMatrix.getTileWidth()) {
                Log.e("GPKGImageTileSource", "Tile widths must match between levels.");
                return;
            }

            TileMatrixSet tileMatrixSet = tileDao.getTileMatrixSet();
            double xSridUnitsPerTile = n * tileMatrix.getPixelXSize();
            double ySridUnitsPerTile = n * tileMatrix.getPixelYSize();
            double xOffset = (tileMatrixSet.getMinX() - projMinX) / xSridUnitsPerTile;
            double yOffset = (projMaxY - tileMatrixSet.getMaxY()) / ySridUnitsPerTile;

            Integer[] offsets = new Integer[2];
            offsets[0] = (int) Math.round(xOffset);
            offsets[1] = (int) Math.round(yOffset);
            tileOffsets.put(z, offsets);
        }

        if (n == -1) {
            Log.e("GPKGImageTileSource", "No valid zoom levels found.");
            return;
        }

        tileRetrieve = new GeoPackageTileRetriever(tileDao);

        valid = true;
    }


    public CoordSystem getCoordSystem() {
        return coordSys;
    }

    public int getMinZoom() {
        return (int) tileDao.getMinZoom();
    }

    public int getMaxZoom() {
        return (int) tileDao.getMaxZoom();
    }

    public byte[] getDataTile(MaplyTileID tileID)
    {
        Integer[] offsets = tileOffsets.get(tileID.level);
        int newX = tileID.x - offsets[0];
        int newY = ((1 << tileID.level) - tileID.y - 1) - offsets[1];

        TileRow tileRow;
        GeoPackageTile tile;
        synchronized (gpkg) {
            tileRow = tileDao.queryForTile(newX,newY,tileID.level);
        }
        if (tileRow != null)
            return tileRow.getTileData();

        return null;
    }
}
