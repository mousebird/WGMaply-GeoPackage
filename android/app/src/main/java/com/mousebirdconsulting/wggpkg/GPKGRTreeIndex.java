package com.mousebirdconsulting.wggpkg;

import android.content.ContentValues;
import android.util.Log;

import java.sql.ResultSet;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import mil.nga.geopackage.BoundingBox;
import mil.nga.geopackage.GeoPackageCore;
import mil.nga.geopackage.core.srs.SpatialReferenceSystem;
import mil.nga.geopackage.core.srs.SpatialReferenceSystemDao;
import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.db.GeoPackageDataType;
import mil.nga.geopackage.extension.BaseExtension;
import mil.nga.geopackage.extension.index.GeometryIndex;
import mil.nga.geopackage.features.user.FeatureCursor;
import mil.nga.geopackage.features.user.FeatureDao;
import mil.nga.geopackage.features.user.FeatureRow;
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


    public GPKGRTreeIndex(String database, GeoPackageConnection db, GeoPackageCore geoPackage, FeatureDao featureDao) {
        super(geoPackage);

        this.featureDao = featureDao;
        tableName = "rtree_" + featureDao.getTableName() + "_" + featureDao.getGeometryColumnName();

        List<GPKGRTreeIndexColumn> columns = Arrays.asList(
                new GPKGRTreeIndexColumn(0, "id", GeoPackageDataType.INT, null, true, 0, true),
                new GPKGRTreeIndexColumn(1, "minx", GeoPackageDataType.FLOAT, null, true, 0, false),
                new GPKGRTreeIndexColumn(2, "maxx", GeoPackageDataType.FLOAT, null, true, 0, false),
                new GPKGRTreeIndexColumn(3, "miny", GeoPackageDataType.FLOAT, null, true, 0, false),
                new GPKGRTreeIndexColumn(4, "maxy", GeoPackageDataType.FLOAT, null, true, 0, false));

        GPKGRTreeIndexTable table = new GPKGRTreeIndexTable(tableName, columns);



        GPKGRTreeIndexConnection rtreeIndexDb = new GPKGRTreeIndexConnection(db);

        rTreeIndexDao = new GPKGRTreeIndexDao(database, db, rtreeIndexDb, table);



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
            if (rTreeIndexDao.count() != featureDao.count()) {

                SpatialReferenceSystemDao srsDao = geoPackage.getSpatialReferenceSystemDao();
                Projection projFrom = ProjectionFactory.getProjection(featureDao.getProjection().getEpsg());
                Projection projTo = ProjectionFactory.getProjection(4326);
                ProjectionTransform projTransform = projFrom.getTransformation(projTo);
                GeometryProjectionTransform transform = new GeometryProjectionTransform(projTransform);


                // TODO: how to detect if rtree vtable exists but isn't fully populated?
                if (rTreeIndexDao.count() == 0)
                    rTreeIndexDao.getDatabaseConnection().execSQL("CREATE VIRTUAL TABLE " + tableName + " USING rtree(id, minx, maxx, miny, maxy);");

                FeatureCursor cursor = featureDao.query(null, null, null, null, "id");
                int featureRowIdx = 0;
                int featureRowSkip = rTreeIndexDao.count();

                List<GPKGRTreeIndexColumn> columns = rTreeIndexDao.getTable().getColumns();

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
                }
                cursor.close();


            } else {
                // TODO: progress interface has no complete ??

            }
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

}
