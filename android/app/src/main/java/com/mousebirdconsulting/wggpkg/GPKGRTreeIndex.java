package com.mousebirdconsulting.wggpkg;

import android.content.ContentValues;
import android.database.Cursor;
import android.database.sqlite.SQLiteException;
import android.util.Log;

import com.j256.ormlite.dao.GenericRawResults;

import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import mil.nga.geopackage.BoundingBox;
import mil.nga.geopackage.GeoPackage;
import mil.nga.geopackage.GeoPackageCore;
import mil.nga.geopackage.core.srs.SpatialReferenceSystem;
import mil.nga.geopackage.core.srs.SpatialReferenceSystemDao;
import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.db.GeoPackageDataType;
import mil.nga.geopackage.extension.BaseExtension;
import mil.nga.geopackage.extension.index.FeatureTableIndex;
import mil.nga.geopackage.extension.index.GeometryIndex;
import mil.nga.geopackage.factory.GeoPackageCursorWrapper;
import mil.nga.geopackage.features.user.FeatureCursor;
import mil.nga.geopackage.features.user.FeatureDao;
import mil.nga.geopackage.features.user.FeatureRow;
import mil.nga.geopackage.features.user.FeatureTable;
import mil.nga.geopackage.geom.GeoPackageGeometryData;
import mil.nga.geopackage.io.GeoPackageProgress;
import mil.nga.geopackage.projection.GeometryProjectionTransform;
import mil.nga.geopackage.projection.Projection;
import mil.nga.geopackage.projection.ProjectionFactory;
import mil.nga.geopackage.projection.ProjectionTransform;
import mil.nga.wkb.geom.Geometry;
import mil.nga.wkb.geom.GeometryEnvelope;
import mil.nga.wkb.util.GeometryEnvelopeBuilder;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndex extends BaseExtension {

    /**
     * Feature DAO
     */
    private final FeatureDao featureDao;

    private String tableName;

    private GPKGRTreeIndexDao rTreeIndexDao;

    protected GeoPackageProgress progress;


    public GPKGRTreeIndex(String database, GeoPackageConnection db, GeoPackage geoPackage, FeatureDao featureDao) {
        super(geoPackage);

        this.featureDao = featureDao;
        tableName = "rtree_" + featureDao.getTableName() + "_" + featureDao.getGeometryColumnName();

        List<GPKGRTreeIndexColumn> columns = Arrays.asList(
                new GPKGRTreeIndexColumn(0, "id", GeoPackageDataType.INT, null, true, 0, true),
                new GPKGRTreeIndexColumn(1, "minx", GeoPackageDataType.FLOAT, null, true, 0, false),
                new GPKGRTreeIndexColumn(2, "maxx", GeoPackageDataType.FLOAT, null, true, 0, false),
                new GPKGRTreeIndexColumn(3, "miny", GeoPackageDataType.FLOAT, null, true, 0, false),
                new GPKGRTreeIndexColumn(4, "maxy", GeoPackageDataType.FLOAT, null, true, 0, false));

        final GPKGRTreeIndexTable table = new GPKGRTreeIndexTable(tableName, columns);



        GPKGRTreeIndexConnection rtreeIndexDb = new GPKGRTreeIndexConnection(db);

        rTreeIndexDao = new GPKGRTreeIndexDao(database, db, rtreeIndexDb, table);


        geoPackage.registerTable(tableName,
                new GeoPackageCursorWrapper() {
                    @Override
                    public Cursor wrapCursor(Cursor cursor) {
                        return new GPKGRTreeIndexCursor(table, cursor);
                    }
                });



    }

    /**
     * Set the progress tracker
     *
     * @param progress
     */
    public void setProgress(GeoPackageProgress progress) {
        this.progress = progress;
    }


    public void indexTable() {
        try {

            GenericRawResults<String[]> rawResults = geoPackage.getContentsDao().queryRaw("SELECT * FROM sqlite_master WHERE name='" + tableName + "';");
            boolean rtreeIndexCreated = (rawResults.getResults().size() > 0);

            //if (rTreeIndexDao.count() != featureDao.count()) {
            if (!rtreeIndexCreated)
                rTreeIndexDao.getDatabaseConnection().execSQL("CREATE VIRTUAL TABLE " + tableName + " USING rtree(id, minx, maxx, miny, maxy);");

            SpatialReferenceSystemDao srsDao = geoPackage.getSpatialReferenceSystemDao();
            Projection projFrom = featureDao.getProjection();
            Projection projTo = ProjectionFactory.getProjection(4326);
            ProjectionTransform projTransform = projFrom.getTransformation(projTo);
            GeometryProjectionTransform transform = new GeometryProjectionTransform(projTransform);

            int featureRowIdx = 0;
            int featureRowSkip = rTreeIndexDao.count();

            List<GPKGRTreeIndexColumn> columns = rTreeIndexDao.getTable().getColumns();

            FeatureCursor cursor = featureDao.query(null, null, null, null, featureDao.getTable().getPkColumn().getName());

            if (featureRowSkip < cursor.getCount()) {

                while ((progress == null || progress.isActive()) && cursor.moveToNext()) {
                    if (featureRowIdx < featureRowSkip) {
                        featureRowIdx++;
                        continue;
                    }
                    FeatureRow featureRow = cursor.getRow();
                    GeoPackageGeometryData geometryData = featureRow.getGeometry();

                    if (geometryData != null && !geometryData.isEmpty()) {

                        long featureID = featureRow.getId();
                        Geometry geometry = geometryData.getGeometry();
                        geometry = transform.transform(geometry);
                        GeometryEnvelope envelope = GeometryEnvelopeBuilder.buildEnvelope(geometry);
                        if (envelope != null) {
                            GeometryIndex geometryIndex = rTreeIndexDao.populate(featureID, envelope);
                            ContentValues contentValues = new ContentValues();
                            contentValues.put(GPKGRTreeIndexTable.COLUMN_ID, geometryIndex.getGeomId());
                            contentValues.put(GPKGRTreeIndexTable.COLUMN_MINX, geometryIndex.getMinX());
                            contentValues.put(GPKGRTreeIndexTable.COLUMN_MAXX, geometryIndex.getMaxX());
                            contentValues.put(GPKGRTreeIndexTable.COLUMN_MINY, geometryIndex.getMinY());
                            contentValues.put(GPKGRTreeIndexTable.COLUMN_MAXY, geometryIndex.getMaxY());
                            rTreeIndexDao.insert(contentValues);
                        }

                    }
                    featureRowIdx++;
                    if ((featureRowIdx % 1000) == 0)
                        Log.i("GPKGRTreeIndex", "indexing... " + featureRowIdx);
                }
            }

            cursor.close();

        } catch (Exception e) {
            Log.e("GPKGRTreeIndex", "indexTable exception", e);
        }
    }

    public GPKGRTreeIndexCursor query(BoundingBox boundingBox) {
        GeometryEnvelope envelope = boundingBox.buildEnvelope();
        return query(envelope);
    }

    public GPKGRTreeIndexCursor query(GeometryEnvelope envelope) {

        String where =
                rTreeIndexDao.buildWhere("minx", Double.valueOf(envelope.getMaxX()), "<=") +
                " and " +
                rTreeIndexDao.buildWhere("maxx", Double.valueOf(envelope.getMinX()), ">=") +
                " and " +
                rTreeIndexDao.buildWhere("miny", Double.valueOf(envelope.getMaxY()), "<=") +
                " and " +
                rTreeIndexDao.buildWhere("maxy", Double.valueOf(envelope.getMinY()), ">=");


        String[] whereArgs = new String[]{
                String.valueOf(envelope.getMaxX()),
                String.valueOf(envelope.getMinX()),
                String.valueOf(envelope.getMaxY()),
                String.valueOf(envelope.getMinY())};

        GPKGRTreeIndexCursor cursor = rTreeIndexDao.query(where, whereArgs);
        return cursor;
    }


    public FeatureRow getFeatureRow(GPKGRTreeIndexRow rTreeIndexRow) {
        GeometryIndex geometryIndex = rTreeIndexRow.getGeometryIndex();
        return featureDao.queryForIdRow(geometryIndex.getGeomId());
    }

    public BoundingBox getMinimalBoundingBox() {
        return rTreeIndexDao.getMinimalBoundingBox();
    }

}
