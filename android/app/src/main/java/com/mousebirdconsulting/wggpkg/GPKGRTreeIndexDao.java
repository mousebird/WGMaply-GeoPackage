package com.mousebirdconsulting.wggpkg;


import android.database.Cursor;

import mil.nga.geopackage.BoundingBox;
import mil.nga.geopackage.GeoPackageException;
import mil.nga.geopackage.core.contents.Contents;
import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.extension.index.GeometryIndex;
import mil.nga.geopackage.user.UserDao;
import mil.nga.wkb.geom.GeometryEnvelope;


/**
 * Created by rghosh on 2017-05-17.
 */

public class GPKGRTreeIndexDao extends UserDao<GPKGRTreeIndexColumn, GPKGRTreeIndexTable, GPKGRTreeIndexRow, GPKGRTreeIndexCursor>  {

    /**
     * Attributes connection
     */
    private final GPKGRTreeIndexConnection rtreeIndexDb;


    /**
     * Constructor
     *
     * @param database     database
     * @param db           db connection
     * @param rtreeIndexDb rtree index connection
     * @param table        rtree index table
     */
    public GPKGRTreeIndexDao(String database, GeoPackageConnection db,
                             GPKGRTreeIndexConnection rtreeIndexDb, GPKGRTreeIndexTable table) {
        super(database, db, rtreeIndexDb, table);

        this.rtreeIndexDb = rtreeIndexDb;
//        if (table.getContents() == null) {
//            throw new GeoPackageException(GPKGRTreeIndexTable.class.getSimpleName()
//                    + " " + table.getTableName() + " has null "
//                    + Contents.class.getSimpleName());
//        }
    }

    public BoundingBox getBoundingBox() {
        // TODO: implement this
        return new BoundingBox(0, 0, 0, 0);
    }

    @Override
    public GPKGRTreeIndexRow newRow() {
        return new GPKGRTreeIndexRow(getTable());
    }

    GeometryIndex populate(long geomId, GeometryEnvelope envelope) {
        GeometryIndex geometryIndex = new GeometryIndex();
        geometryIndex.setGeomId(geomId);
        geometryIndex.setMinX(envelope.getMinX());
        geometryIndex.setMaxX(envelope.getMaxX());
        geometryIndex.setMinY(envelope.getMinY());
        geometryIndex.setMaxY(envelope.getMaxY());
        return geometryIndex;
    }

    public BoundingBox getMinimalBoundingBox() {
        String queryString = "SELECT MIN(minx) AS minx, MAX(maxx) AS maxx, MIN(miny) AS miny, MAX(maxy) AS maxy FROM " + getTableName();
        Cursor cursor = getDatabaseConnection().rawQuery(queryString, null);

        Double minx = null;
        Double maxx = null;
        Double miny = null;
        Double maxy = null;

        if (cursor.moveToNext()) {
            minx = cursor.getDouble(0);
            maxx = cursor.getDouble(1);
            miny = cursor.getDouble(2);
            maxy = cursor.getDouble(3);
        }
        cursor.close();

        if (minx==null || maxx==null || miny==null || maxy==null)
            return null;

        return new BoundingBox(minx, maxx, miny, maxy);
    }

}
