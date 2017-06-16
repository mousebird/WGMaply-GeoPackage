package com.mousebirdconsulting.wggpkg;


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

}
