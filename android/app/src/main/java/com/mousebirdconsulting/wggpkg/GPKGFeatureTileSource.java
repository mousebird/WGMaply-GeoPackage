package com.mousebirdconsulting.wggpkg;

import android.content.res.AssetManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.util.DisplayMetrics;
import android.util.Log;

import com.mousebird.maply.ComponentObject;
import com.mousebird.maply.LayerThread;
import com.mousebird.maply.MaplyBaseController;
import com.mousebird.maply.MaplyTileID;
import com.mousebird.maply.Mbr;
import com.mousebird.maply.Point2d;
import com.mousebird.maply.QuadPagingLayer;
import com.mousebird.maply.QuadPagingLayer.PagingInterface;
import com.mousebird.maply.ScreenObject;
import com.mousebird.maply.BaseInfo;
import com.mousebird.maply.VectorInfo;
import com.mousebird.maply.VectorObject;
import com.mousebird.maply.WideVectorInfo;
import com.mousebird.maply.sld.sldstyleset.SLDStyleSet;

//import android.database.sqlite.SQLiteDatabase;
import org.sqlite.database.sqlite.SQLiteCursor;
import org.sqlite.database.sqlite.SQLiteDatabase;

import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import mil.nga.geopackage.BoundingBox;
import mil.nga.geopackage.GeoPackage;
import mil.nga.geopackage.core.srs.SpatialReferenceSystem;
import mil.nga.geopackage.core.srs.SpatialReferenceSystemDao;
import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.features.user.FeatureDao;
import mil.nga.geopackage.projection.GeometryProjectionTransform;
import mil.nga.geopackage.projection.Projection;
import mil.nga.geopackage.projection.ProjectionFactory;
import mil.nga.geopackage.projection.ProjectionTransform;
import mil.nga.wkb.geom.GeometryType;

import static com.mousebird.maply.MaplyBaseController.FeatureDrawPriorityBase;
import static com.mousebird.maply.MaplyBaseController.ImageLayerDrawPriorityDefault;

/**
 * Created by rghosh on 2017-06-13.
 */

public class GPKGFeatureTileSource implements PagingInterface {

    public static final int GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT = 20000;
    public static final int GPKG_FEATURE_TILE_SOURCE_TARGET_TILE_COUNT = 128;

    int minZoom = 0;
    int maxZoom = 0;
    int targetLevel = 0;
    Point2d center = null;
    GeoPackage geoPackage;
    FeatureDao featureDao;
    GPKGRTreeIndex rTreeIndex;
    VectorInfo gridVectorInfo;
    GeometryProjectionTransform geomProjTransform;
    Bitmap markerBitmap;
    HashMap<Integer, HashMap<Integer, HashMap<Integer, Boolean>>> loadedTiles;


    AssetManager assetManager;
    String sldFileName;
    DisplayMetrics displayMetrics;
    SLDStyleSet styleSet;
    GPKGFeatureTileStyler tileParser;



    public GPKGFeatureTileSource(String database, GeoPackage geoPackage, GeoPackageConnection geoPackageConnection, FeatureDao featureDao, String sldFileName, AssetManager assetManager, DisplayMetrics displayMetrics, HashMap<String, List<Number>> bounds, int inMinZoom, int inMaxZoom) {
        minZoom = inMinZoom;
        maxZoom = inMaxZoom;
        this.sldFileName = sldFileName;
        this.assetManager = assetManager;
        this.displayMetrics = displayMetrics;
        this.geoPackage = geoPackage;
        synchronized (this.geoPackage) {
            this.featureDao = featureDao;
            if (this.featureDao == null) {
                Log.i("GPKGFeatureTileSource", "GPKGFeatureTileSource: Error accessing Feature DAO.");
                return;
            }

            gridVectorInfo = new VectorInfo();
            gridVectorInfo.setColor(Color.GREEN);
            gridVectorInfo.setEnable(false);
            gridVectorInfo.setLineWidth(5.0f);
            gridVectorInfo.setDrawPriority(FeatureDrawPriorityBase + 220);

            //TODO: assign markerBitmap
            //markerBitmap =

            SpatialReferenceSystemDao srsDao = geoPackage.getSpatialReferenceSystemDao();
            SpatialReferenceSystem srs;
            try {

                Projection featureDaoProjection = featureDao.getProjection();
                srs = srsDao.getOrCreateCode(
                        featureDaoProjection.getAuthority(),
                        Long.parseLong(featureDaoProjection.getCode()));
                //srs = srsDao.queryForOrganizationCoordsysId(featureDao.getProjection().getEpsg());
            } catch (SQLException e) {
                // TODO: handle error
                return;
            }

            List<Number> srsBounds = bounds.get(String.valueOf(srs.getOrganizationCoordsysId()));

            BoundingBox bbox = new BoundingBox(
                    srsBounds.get(0).doubleValue(),
                    srsBounds.get(2).doubleValue(),
                    srsBounds.get(1).doubleValue(),
                    srsBounds.get(3).doubleValue());

            boolean isDegree = (srsBounds.get(6).intValue() == 1);

            Projection projFrom = featureDao.getProjection();
            Projection proj4326 = ProjectionFactory.getProjection(4326);
            ProjectionTransform projTransform = projFrom.getTransformation(proj4326);
            geomProjTransform = new GeometryProjectionTransform(projTransform);

            if (isDegree) {
                bbox = new BoundingBox(
                        bbox.getMinLongitude() * 180.0 / Math.PI,
                        bbox.getMaxLongitude() * 180.0 / Math.PI,
                        bbox.getMinLatitude() * 180.0 / Math.PI,
                        bbox.getMaxLatitude() * 180.0 / Math.PI);
            } else {
                bbox = projTransform.transform(bbox);
            }

            //testSQLiteRTree();

            rTreeIndex = new GPKGRTreeIndex(database, geoPackageConnection, geoPackage, featureDao);
            rTreeIndex.indexTable();

            BoundingBox gpkgBBox = rTreeIndex.getMinimalBoundingBox();
            BoundingBox gpkgBBoxTransformed = gpkgBBox;
            if (!isDegree)
                gpkgBBoxTransformed = projTransform.transform(gpkgBBox);
            center = new Point2d(
                    (gpkgBBoxTransformed.getMinLongitude()  + gpkgBBoxTransformed.getMaxLongitude())/2.0,
                    (gpkgBBoxTransformed.getMinLatitude()  + gpkgBBoxTransformed.getMaxLatitude())/2.0);

            loadedTiles = new HashMap<>();

            long totalFeatureSizeBytes = getTotalFeaturesSize();
            int numFeatures = featureDao.count();
            if (totalFeatureSizeBytes == -1 || numFeatures < 1) {
                // TODO: handle error
                return;
            }

            float avgFeatureSizeBytes  = (float)totalFeatureSizeBytes / (float)numFeatures;

            /*  This is just a heuristic calculation to approximate the number of points per geometry in the table.
                The 43.0 offset is 40 + 3. 40 is the estimated GeoPackageBinaryHeader size. 3 is the approximate constant contribution to the WKB size.  And 18 is the approximate variable contribution to the WKB size.
             */
            float avgNumPoints = Math.max( (avgFeatureSizeBytes - 43.0f) / 18.0f, 1.0f);

            GeometryType geomType = featureDao.getGeometryType();
            int maxFeatures = (int)(GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT / avgNumPoints);

            float featuresPerTile = (float)maxFeatures / (float)GPKG_FEATURE_TILE_SOURCE_TARGET_TILE_COUNT * 0.5f;

            if ((gpkgBBox.getMinLongitude() == gpkgBBox.getMaxLongitude()) || (gpkgBBox.getMinLatitude() == gpkgBBox.getMaxLatitude()))
                targetLevel = minZoom;
            else {
                targetLevel = maxZoom;
                for (int level=minZoom; level<maxZoom; level++) {
                    double xSridUnitsPerTile = (bbox.getMaxLongitude() - bbox.getMinLongitude()) / (1 << level);
                    double ySridUnitsPerTile = (bbox.getMaxLatitude() - bbox.getMinLatitude()) / (1 << level);

                    double bboxSnappedMinX = bbox.getMinLongitude() + Math.round((gpkgBBox.getMinLongitude() - bbox.getMinLongitude()) / xSridUnitsPerTile) * xSridUnitsPerTile;
                    double bboxSnappedMinY = bbox.getMinLatitude() + Math.round((gpkgBBox.getMinLatitude() - bbox.getMinLatitude()) / ySridUnitsPerTile) * ySridUnitsPerTile;

                    double bboxSnappedMaxX = bbox.getMaxLongitude() - Math.round((bbox.getMaxLongitude() - gpkgBBox.getMaxLongitude()) / xSridUnitsPerTile) * xSridUnitsPerTile;
                    double bboxSnappedMaxY = bbox.getMaxLatitude() - Math.round((bbox.getMaxLatitude() - gpkgBBox.getMaxLatitude()) / ySridUnitsPerTile) * ySridUnitsPerTile;

                    int numTiles = (int)((bboxSnappedMaxX - bboxSnappedMinX) / xSridUnitsPerTile) * (int)((bboxSnappedMaxY - bboxSnappedMinY) / ySridUnitsPerTile);

                    if ( ((float)numFeatures / (float)numTiles) < featuresPerTile ) {
                        targetLevel = level;
                        break;
                    }



                }
            }
        }

    }

    void testSQLiteRTree() {


// get the SQLite version
        String query = "select sqlite_version() AS sqlite_version";
        SQLiteDatabase db = SQLiteDatabase.openOrCreateDatabase(":memory:", null);
        Cursor cursor = db.rawQuery(query, null);
        String sqliteVersion = "";
        if (cursor.moveToNext()) {
            sqliteVersion = cursor.getString(0);
        }

// do some R*Tree things (this will fail for the standard SQLite)
        db.execSQL("CREATE VIRTUAL TABLE demo_index USING rtree(id, minX, maxX, minY, maxY);");
        db.execSQL("INSERT INTO demo_index VALUES(1,-80.7749, -80.7747, 35.3776, 35.3778);");
        db.execSQL("INSERT INTO demo_index VALUES(2,-81.0, -79.6, 35.0, 36.2);");

        cursor = db.rawQuery("SELECT id FROM demo_index WHERE minX>=-81.08 AND maxX<=-80.58 AND minY>=35.00  AND maxY<=35.44;", null);

        int id = -1;
        if (cursor.moveToFirst()) {
            do {
                id = cursor.getInt(0);
            } while (cursor.moveToNext());
        }
        db.close();
    }


    /**
     * Min zoom level, probably 0.
     */
    @Override
    public int minZoom() {
        return minZoom;
    }

    /**
     * Max zoom level, typically 14 for vector tiles.
     */
    @Override
    public int maxZoom() {
        return maxZoom;
    }


    public Point2d center() {
        return center;
    }

    // The paging layer calls us here to start paging a tile
    @Override
    public void startFetchForTile(final QuadPagingLayer layer, final MaplyTileID tileID)
    {
        final Mbr geoBbox =  layer.geoBoundsForTile(tileID);

        synchronized(this) {
            if (tileParser == null) {
                try {
                    styleSet = new SLDStyleSet(layer.maplyControl, assetManager, sldFileName, displayMetrics, false, 0);
                    styleSet.loadSldInputStream();
                    tileParser = new GPKGFeatureTileStyler(styleSet, layer.maplyControl, targetLevel, maxZoom, rTreeIndex, geomProjTransform);
                } catch (Exception e) {
                    // TODO: handle error
                    Log.e("GPKGFeatureTileSource", "Exception constructing tileParser", e);
                }
            }
        }

        LayerThread layerThread = layer.maplyControl.getWorkingThread();

        class FetchRunnable implements Runnable {

            @Override
            public void run() {
                if (isParentLoaded(tileID)) {
                    layer.tileFailedToLoad(tileID);
                    return;
                }

                Mbr geoBboxDeg = new Mbr(
                        new Point2d(geoBbox.ll.getX()*180.0/Math.PI, geoBbox.ll.getY()*180.0/Math.PI),
                        new Point2d(geoBbox.ur.getX()*180.0/Math.PI, geoBbox.ur.getY()*180.0/Math.PI));

                int n;
                ArrayList<ComponentObject> compObjs = new ArrayList<>();
                boolean complete = true;

                synchronized (geoPackage) {
                    n = tileParser.buildObjects(tileID, geoBbox, geoBboxDeg, compObjs);
                }

                if (compObjs.size() == 0) {
                    complete = false;
                    if (n > 0 && tileID.level > 5) {
                        VectorObject vectorObject = new VectorObject();
                        vectorObject.addLinear(new Point2d[]{
                                new Point2d(geoBbox.ll.getX(), geoBbox.ll.getY()),
                                new Point2d(geoBbox.ur.getX(), geoBbox.ll.getY()),
                                new Point2d(geoBbox.ur.getX(), geoBbox.ur.getY()),
                                new Point2d(geoBbox.ll.getX(), geoBbox.ur.getY()),
                                new Point2d(geoBbox.ll.getX(), geoBbox.ll.getY())
                        });
                        ComponentObject vecCompObj = layer.maplyControl.addVector(vectorObject, gridVectorInfo, MaplyBaseController.ThreadMode.ThreadCurrent);
                        compObjs.add(vecCompObj);

                    }
                }

                if (n > 0) {
                    layer.addData(compObjs, tileID);
                }

                if (complete)
                    setLoaded(tileID);

                layer.tileDidLoad(tileID);
            }
        }

        FetchRunnable fetchRunnable = new FetchRunnable();
        layerThread.addTask(fetchRunnable);

    }

    long getTotalFeaturesSize() {
        String queryString = "SELECT SUM(LENGTH(" + featureDao.getGeometryColumnName() + ")) FROM " + featureDao.getTableName() + ";";
        Cursor cursor = featureDao.getDatabaseConnection().rawQuery(queryString, null);
        long n = -1;
        if (cursor.moveToNext())
            n = cursor.getLong(0);
        cursor.close();
        return n;
    }

    @Override
    public void tileDidUnload(MaplyTileID tileID)
    {
        clearLoaded(tileID);
    }

    void setLoaded(MaplyTileID tileID) {
        synchronized (this) {
            //HashMap<Integer, HashMap<Integer, HashMap<Integer, Boolean>>> loadedTiles;

            HashMap<Integer, HashMap<Integer, Boolean>> levelDict = loadedTiles.get(tileID.level);
            if (levelDict == null) {
                levelDict = new HashMap<>();
                loadedTiles.put(tileID.level, levelDict);
            }

            HashMap<Integer, Boolean> columnDict = levelDict.get(tileID.x);
            if (columnDict == null) {
                columnDict = new HashMap<>();
                levelDict.put(tileID.x, columnDict);
            }

            columnDict.put(tileID.y, Boolean.TRUE);
        }
    }

    void clearLoaded(MaplyTileID tileID) {
        synchronized (this) {
            HashMap<Integer, HashMap<Integer, Boolean>> levelDict = loadedTiles.get(tileID.level);
            if (levelDict == null)
                return;

            HashMap<Integer, Boolean> columnDict = levelDict.get(tileID.x);
            if (columnDict == null)
                return;

            if (columnDict.containsKey(tileID.y))
                columnDict.remove(tileID.y);
            if (columnDict.size() == 0)
                levelDict.remove(tileID.x);
            if (levelDict.size() == 0)
                loadedTiles.remove(tileID.level);

        }
    }

    boolean isParentLoaded(MaplyTileID tileID) {
        MaplyTileID parentTileID = new MaplyTileID(tileID.x/2, tileID.y/2, tileID.level-1);

        HashMap<Integer, HashMap<Integer, Boolean>> levelDict = loadedTiles.get(parentTileID.level);
        if (levelDict == null)
            return false;

        HashMap<Integer, Boolean> columnDict = levelDict.get(parentTileID.x);
        if (columnDict == null)
            return false;

        return columnDict.containsKey(parentTileID.y);
    }

    @Override
    public void clear()
    {
    }

}
