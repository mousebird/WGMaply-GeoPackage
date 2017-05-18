package com.mousebirdconsulting.wggpkg;

import mil.nga.geopackage.db.GeoPackageConnection;
import mil.nga.geopackage.user.UserConnection;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndexConnection extends UserConnection<GPKGRTreeIndexColumn, GPKGRTreeIndexTable, GPKGRTreeIndexRow, GPKGRTreeIndexCursor> {

    /**
     * Constructor
     *
     * @param database
     */
    public GPKGRTreeIndexConnection(GeoPackageConnection database) {
        super(database);
    }

}
