package com.mousebirdconsulting.wggpkg;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.util.Log;

import com.mousebird.maply.CoordSystem;
import com.mousebird.maply.MaplyImageTile;
import com.mousebird.maply.MaplyTileID;
import com.mousebird.maply.Mbr;
import com.mousebird.maply.Point2d;
import com.mousebird.maply.Proj4CoordSystem;
import com.mousebird.maply.QuadImageTileLayer;
import com.mousebird.maply.QuadImageTileLayerInterface;

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

/**
 * Implements an image tile source from a GeoPackage table.
 */
public class GPKGImageTileSource implements QuadImageTileLayer.TileSource {

    TileDao tileDao;
    int minZoom = 0;
    int maxZoom = 0;
    CoordSystem coordSys = null;
    boolean valid = false;
    HashMap<Integer,Integer[]> tileOffsets = new HashMap<Integer,Integer[]>();

    public GPKGImageTileSource(String database, GeoPackage geoPackage, GeoPackageConnection geoPackageConnection,
                               TileDao inTileDao, HashMap<String, List<Number>> bounds) {

        tileDao = inTileDao;
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
        mbr.addPoint(new Point2d(bbox.getMinLongitude(),bbox.getMinLatitude()));
        mbr.addPoint(new Point2d(bbox.getMaxLongitude(),bbox.getMaxLatitude()));
        coordSys.setBounds(mbr);

        int n = -1;
        for (int z=(int)tileDao.getMinZoom(); z<=(int)tileDao.getMaxZoom(); z++)
        {
            TileMatrix tileMatrix = tileDao.getTileMatrix(z);

            if (tileMatrix.getTileWidth() != tileMatrix.getTileHeight())
            {
                Log.e("GPKGImageTileSource","Tile width and height must match.");
                return;
            }

            if (n == -1) {
                n = (int)tileMatrix.getTileWidth();
                if (!(n>0 && ((n & (n-1)) == 0))) {
                    Log.e("GPKGImageTileSource","Tile size must be a positive power of 2.");
                    return;
                }
            } else if (n != tileMatrix.getTileWidth())
            {
                Log.e("GPKGImageTileSource","Tile widths must match between levels.");
                return;
            }

            TileMatrixSet tileMatrixSet = tileDao.getTileMatrixSet();
            double xSridUnitsPerTile = n * tileMatrix.getPixelXSize();
            double ySridUnitsPerTile = n * tileMatrix.getPixelYSize();
            double xOffset = (tileMatrixSet.getMinX() - projMinX) / xSridUnitsPerTile;
            double yOffset = (projMaxY - tileMatrixSet.getMaxY() ) / ySridUnitsPerTile;

            Integer[] offsets = new Integer[2];
            offsets[0] = (int)Math.round(xOffset);  offsets[1] = (int)Math.round(yOffset);
            tileOffsets.put(z,offsets);
        }

        if (n == -1)
        {
            Log.e("GPKGImageTileSource","No valid zoom levels found.");
            return;
        }

        valid = true;
    }

    /**
     * Returns true if the tile source set up correctly.
     */
    public boolean isValid()
    {
        return valid;
    }

    public CoordSystem getCoordSys()
    {
        return coordSys;
    }

    public int minZoom()
    {
        return (int)tileDao.getMinZoom();
    }

    public int maxZoom()
    {
        return (int)tileDao.getMaxZoom();
    }

    public int pixelsPerSide()
    {
        return 256;
    }

    public boolean validTile(MaplyTileID var1, Mbr var2)
    {
        return true;
    }

    public void startFetchForTile(QuadImageTileLayerInterface quadLayer, MaplyTileID tileID, int frame)
    {
        GeoPackageTileRetriever tileRetrieve = new GeoPackageTileRetriever(tileDao);

        Integer[] offsets = tileOffsets.get(tileID.level);
        int newX = tileID.x - offsets[0];
        int newY = ((1 << tileID.level) - tileID.y - 1) - offsets[1];
        GeoPackageTile tile = tileRetrieve.getTile(newX,newY,tileID.level);

        // Make a bitmap of it and return it
        byte[] tileData = tile.getData();
        if (tileData != null)
        {
            Bitmap bm = BitmapFactory.decodeByteArray(tileData,0,tileData.length);
            MaplyImageTile imageTile = new MaplyImageTile(bm);

            quadLayer.loadedTile(tileID,frame,imageTile);
        }
    }

    public void clear(QuadImageTileLayerInterface var1)
    {
        tileDao = null;
    }

}