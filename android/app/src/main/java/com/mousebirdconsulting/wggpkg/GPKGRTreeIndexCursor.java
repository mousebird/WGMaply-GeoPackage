package com.mousebirdconsulting.wggpkg;

import android.database.Cursor;

import mil.nga.geopackage.user.UserCursor;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndexCursor extends UserCursor<GPKGRTreeIndexColumn, GPKGRTreeIndexTable, GPKGRTreeIndexRow> {

    /**
     * Constructor
     *
     * @param table  attributes table
     * @param cursor cursor
     */
    public GPKGRTreeIndexCursor(GPKGRTreeIndexTable table, Cursor cursor) {
        super(table, cursor);
    }

    /**
     * {@inheritDoc}
     */
    @Override
    public GPKGRTreeIndexRow getRow(int[] columnTypes, Object[] values) {
        GPKGRTreeIndexRow row = new GPKGRTreeIndexRow(getTable(), columnTypes, values);
        return row;
    }
}
