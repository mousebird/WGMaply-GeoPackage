package com.mousebirdconsulting.wggpkg;

import java.util.List;

import mil.nga.geopackage.GeoPackageException;
import mil.nga.geopackage.core.contents.Contents;
import mil.nga.geopackage.core.contents.ContentsDataType;
import mil.nga.geopackage.user.UserTable;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndexTable extends UserTable<GPKGRTreeIndexColumn> {


//    /**
//     * Foreign key to Contents
//     */
//    private Contents contents;
//
//
    /**
     * Constructor
     *
     * @param tableName
     *            table name
     * @param columns
     *            attributes columns
     */
    public GPKGRTreeIndexTable(String tableName, List<GPKGRTreeIndexColumn> columns) {
        super(tableName, columns);
    }
//
//    /**
//     * Get the contents
//     *
//     * @return contents
//     */
//    public Contents getContents() {
//        return contents;
//    }
//
//    /**
//     * Set the contents
//     *
//     * @param contents
//     *            contents
//     */
//    public void setContents(Contents contents) {
//        this.contents = contents;
//        if (contents != null) {
//            // Verify the Contents have an attributes data type
//            ContentsDataType dataType = contents.getDataType();
//            if (dataType == null || dataType != ContentsDataType.ATTRIBUTES) {
//                throw new GeoPackageException("The "
//                        + Contents.class.getSimpleName() + " of a "
//                        + GPKGRTreeIndexTable.class.getSimpleName()
//                        + " must have a data type of "
//                        + ContentsDataType.ATTRIBUTES.getName());
//            }
//        }
//    }
}
