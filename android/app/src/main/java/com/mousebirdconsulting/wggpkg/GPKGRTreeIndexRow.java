package com.mousebirdconsulting.wggpkg;

import android.content.ContentValues;

import mil.nga.geopackage.extension.index.GeometryIndex;
import mil.nga.geopackage.user.UserCoreTableReader;
import mil.nga.geopackage.user.UserRow;
import mil.nga.geopackage.user.UserTable;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndexRow extends UserRow<GPKGRTreeIndexColumn, GPKGRTreeIndexTable> {

    /**
     * Constructor
     *
     * @param table
     *            attributes table
     * @param columnTypes
     *            column types
     * @param values
     *            values
     */
    GPKGRTreeIndexRow(GPKGRTreeIndexTable table, int[] columnTypes, Object[] values) {
        super(table, columnTypes, values);
    }

    /**
     * Constructor to create an empty row
     *
     * @param table
     */
    GPKGRTreeIndexRow(GPKGRTreeIndexTable table) {
        super(table);
    }


    public int getMinXColumnIndex() {
        return getTable().getMinXColumnIndex();
    }

    public GPKGRTreeIndexColumn getMinXColumn() {
        return getTable().getMinXColumn();
    }

    public double getMinX() {
        return ((Number) getValue(getMinXColumnIndex())).doubleValue();
    }

    public void setMinX(double minX) {
        setValue(getMinXColumnIndex(), Double.valueOf(minX));
    }



    public int getMaxXColumnIndex() {
        return getTable().getMaxXColumnIndex();
    }

    public GPKGRTreeIndexColumn getMaxXColumn() {
        return getTable().getMaxXColumn();
    }

    public double getMaxX() {
        return ((Number) getValue(getMaxXColumnIndex())).doubleValue();
    }

    public void setMaxX(double maxX) {
        setValue(getMaxXColumnIndex(), Double.valueOf(maxX));
    }



    public int getMinYColumnIndex() {
        return getTable().getMinYColumnIndex();
    }

    public GPKGRTreeIndexColumn getMinYColumn() {
        return getTable().getMinYColumn();
    }


    public double getMinY() {
        return ((Number) getValue(getMinYColumnIndex())).doubleValue();
    }

    public void setMinY(double minY) {
        setValue(getMinYColumnIndex(), Double.valueOf(minY));
    }



    public int getMaxYColumnIndex() {
        return getTable().getMaxYColumnIndex();
    }

    public GPKGRTreeIndexColumn getMaxYColumn() {
        return getTable().getMaxYColumn();
    }

    public double getMaxY() {
        return ((Number) getValue(getMaxYColumnIndex())).doubleValue();
    }

    public void setMaxY(double maxY) {
        setValue(getMaxYColumnIndex(), Double.valueOf(maxY));
    }


    public GeometryIndex getGeometryIndex() {
        GeometryIndex geometryIndex = new GeometryIndex();
        geometryIndex.setGeomId( ((Number)getValue(getPkColumnIndex())).longValue() );
        geometryIndex.setMinX(getMinX());
        geometryIndex.setMaxX(getMaxX());
        geometryIndex.setMinY(getMinY());
        geometryIndex.setMaxY(getMaxY());
        return geometryIndex;
    }

}
