package com.mousebirdconsulting.wggpkg;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.os.AsyncTask;
import android.util.Log;

import com.mousebird.maply.CoordSystem;
import com.mousebird.maply.MaplyBaseController;
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
import mil.nga.geopackage.tiles.user.TileRow;

/**
 * Implements an image tile source from a GeoPackage table.
 */
public class GPKGImageTileSource implements QuadImageTileLayer.TileSource {
    MaplyBaseController control = null;
    TileDao tileDao;
    int minZoom = 0;
    int maxZoom = 0;
    int zoomOffset = 0;
    CoordSystem coordSys = null;
    boolean valid = false;
    HashMap<Integer,Integer[]> tileOffsets = new HashMap<Integer,Integer[]>();
    GeoPackage gpkg;

    public GPKGImageTileSource(MaplyBaseController inControl,String database, GeoPackage geoPackage, GeoPackageConnection geoPackageConnection,
                               TileDao inTileDao, HashMap<String, List<Number>> bounds) {
        control = inControl;
        gpkg = geoPackage;
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

        TileMatrixSet tileMatrixSet = tileDao.getTileMatrixSet();
        BoundingBox gpkgBBox = tileMatrixSet.getBoundingBox();

        if (!isDegree) {
            // The data on projection extents is lacking.  We will adjust the
            //   assumed projection bounds to harmonize them with the layer bounds.
            // FIXME: We should not have to do this, and it may not be robust.
            // https://github.com/mousebird/WGMaply-GeoPackage/issues/1

            TileMatrix tileMatrix = tileDao.getTileMatrix(tileDao.getMinZoom());
            if (tileMatrix == null) {
                return;
            }

            double xSridUnitsPerTile = tileMatrix.getTileWidth() * tileMatrix.getPixelXSize();
            double ySridUnitsPerTile = tileMatrix.getTileHeight() * tileMatrix.getPixelYSize();

            // First guess at projection bounds.
            // Projection bounds should be a whole multiple of tile spans away from
            //   the layer bounds.
            mbr.ll.setValue(gpkgBBox.getMinLongitude() -
                    Math.round((gpkgBBox.getMinLongitude() - mbr.ll.getX()) / xSridUnitsPerTile) *
                            xSridUnitsPerTile,
                    gpkgBBox.getMinLatitude() -
                        Math.round((gpkgBBox.getMinLatitude() - mbr.ll.getY()) / ySridUnitsPerTile) *
                            ySridUnitsPerTile);
            mbr.ur.setValue(gpkgBBox.getMaxLongitude() +
                    Math.round((mbr.ur.getX() - gpkgBBox.getMaxLongitude()) / xSridUnitsPerTile) *
                            xSridUnitsPerTile,
                    gpkgBBox.getMaxLatitude() +
                            Math.round((mbr.ur.getY() - gpkgBBox.getMaxLatitude()) / ySridUnitsPerTile) *
                                            ySridUnitsPerTile);

            // Now adjust bounds, if necessary, so that there's the appropriate
            //  power-of-two tile spans between them to conform to the tile pyramid.
            int m = ( 1 << tileDao.getMinZoom()) -
                    (int)(Math.round((mbr.ur.getX() - mbr.ll.getX())) / xSridUnitsPerTile);
            int n = ( 1 << tileDao.getMinZoom()) -
                    (int)(Math.round((mbr.ur.getY() - mbr.ll.getY())) / ySridUnitsPerTile);
            double newLLx = mbr.ll.getX() - (m/2) * xSridUnitsPerTile;
            double newURx = mbr.ur.getX() + (m-m/2) * xSridUnitsPerTile;
            double newLLy = mbr.ll.getY() - (n/2) * ySridUnitsPerTile;
            double newURy = mbr.ur.getY() + (n-n/2) * ySridUnitsPerTile;
            mbr.ll.setValue(newLLx,newLLy);
            mbr.ur.setValue(newURx,newURy);

            projMinX = newLLx;
            projMaxY = newURy;
        }

        coordSys.setBounds(mbr);

        // Some packages have more tiles per zoom level than we'd expect.
        // In theory this can be more flexible, but this works for now
        zoomOffset = 0;
        for (int z=(int)tileDao.getMinZoom(); z<=(int)tileDao.getMaxZoom(); z++)
        {
            TileMatrix tileMatrix = tileDao.getTileMatrix(z);
            int numTiles = 1<<z;
            if (tileMatrix.getMatrixWidth() > numTiles ||
                    tileMatrix.getMatrixHeight() > numTiles) {
                // Note: Should calculate rather than assuming
                zoomOffset = 1;
            }
        }

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

            double xSridUnitsPerTile = n * tileMatrix.getPixelXSize();
            double ySridUnitsPerTile = n * tileMatrix.getPixelYSize();
            double xOffset = (tileMatrixSet.getMinX() - projMinX) / xSridUnitsPerTile;
            double yOffset = (projMaxY - tileMatrixSet.getMaxY() ) / ySridUnitsPerTile;

            Log.d("GPKG","units per tile " + xSridUnitsPerTile + " " + ySridUnitsPerTile);
            Log.d("GPKG","min x y " + tileMatrixSet.getMinX() + " " + tileMatrixSet.getMinY());
            Log.d("GPKG","offset " + z + ":" + " " + xOffset + " " + yOffset);


            Integer[] offsets = new Integer[2];
            offsets[0] = (int)Math.round(xOffset);  offsets[1] = (int)Math.round(yOffset);
            tileOffsets.put(z+zoomOffset,offsets);
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
        return (int)tileDao.getMinZoom()+zoomOffset;
    }

    public int maxZoom()
    {
        return (int)tileDao.getMaxZoom()+zoomOffset;
    }

    public int pixelsPerSide()
    {
        return 256;
    }

    public boolean validTile(MaplyTileID var1, Mbr var2)
    {
        return true;
    }

    public void startFetchForTile(final QuadImageTileLayerInterface quadLayer, final MaplyTileID tileID, final int frame)
    {
        control.getWorkingThread().addTask(new Runnable() {
            @Override
            public void run() {
                GeoPackageTileRetriever tileRetrieve = new GeoPackageTileRetriever(tileDao);

                Integer[] offsets = tileOffsets.get(tileID.level);
                int newX = tileID.x - offsets[0];
                int newY = ((1 << tileID.level) - tileID.y - 1) - offsets[1];
                int level = tileID.level-zoomOffset;
                GeoPackageTile tile = tileRetrieve.getTile(newX,newY,tileID.level);

                Log.d("GPKG","Started loading: " + tileID);

                byte[] tileData = null;
                TileRow tileRow;
                if (gpkg == null || tileDao == null)
                    return;
                synchronized (gpkg) {
                    tileRow = tileDao.queryForTile(newX,newY,level);
                }
                if (tileRow != null) {
                    tileData = tileRow.getTileData();
                }

                Log.d("GPKG","Loaded: " + tileID);

                if (tileData != null) {
                    Bitmap bm = BitmapFactory.decodeByteArray(tileData, 0, tileData.length);
                    MaplyImageTile imageTile = new MaplyImageTile(bm);

                    quadLayer.loadedTile(tileID, frame, imageTile);
                } else
                    quadLayer.loadedTile(tileID, frame, null);
            }
        });
    }

    public void clear(QuadImageTileLayerInterface var1)
    {
        tileDao = null;
    }

}