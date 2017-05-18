package com.mousebirdconsulting.wggpkg;

import mil.nga.geopackage.db.GeoPackageDataType;
import mil.nga.geopackage.user.UserColumn;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndexColumn extends UserColumn {







    /**
     * Constructor
     *
     * @param index
     *            index
     * @param name
     *            name
     * @param dataType
     *            data type
     * @param max
     *            max value
     * @param notNull
     *            not null flag
     * @param defaultValue
     *            default value
     * @param primaryKey
     *            primary key flag
     */
    GPKGRTreeIndexColumn(int index, String name, GeoPackageDataType dataType,
                     Long max, boolean notNull, Object defaultValue, boolean primaryKey) {
        super(index, name, dataType, max, notNull, defaultValue, primaryKey);
    }

}
