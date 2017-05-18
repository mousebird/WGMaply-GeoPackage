package com.mousebirdconsulting.wggpkg;

import mil.nga.geopackage.user.UserRow;

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
}
