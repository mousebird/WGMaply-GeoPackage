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

    public static final String COLUMN_ID = "id";

    public static final String COLUMN_MINX = "minx";

    public static final String COLUMN_MAXX = "maxx";

    public static final String COLUMN_MINY = "miny";

    public static final String COLUMN_MAXY = "maxy";

    private final int minXColumnIndex;

    private final int maxXColumnIndex;

    private final int minYColumnIndex;

    private final int maxYColumnIndex;

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

        Integer minXColumn = null;
        Integer maxXColumn = null;
        Integer minYColumn = null;
        Integer maxYColumn = null;

        for (GPKGRTreeIndexColumn column : columns) {

            String columnName = column.getName();
            int columnIndex = column.getIndex();

            if (columnName.equals(COLUMN_MINX))
                minXColumn = columnIndex;
            else if (columnName.equals(COLUMN_MAXX))
                maxXColumn = columnIndex;
            else if (columnName.equals(COLUMN_MINY))
                minYColumn = columnIndex;
            else if (columnName.equals(COLUMN_MAXY))
                maxYColumn = columnIndex;

        }

        missingCheck(minXColumn, COLUMN_MINX);
        minXColumnIndex = minXColumn;

        missingCheck(maxXColumn, COLUMN_MAXX);
        maxXColumnIndex = maxXColumn;

        missingCheck(minYColumn, COLUMN_MINY);
        minYColumnIndex = minYColumn;

        missingCheck(maxYColumn, COLUMN_MAXY);
        maxYColumnIndex = maxYColumn;

    }

    public int getMinXColumnIndex() {
        return minXColumnIndex;
    }

    public GPKGRTreeIndexColumn getMinXColumn() {
        return getColumn(minXColumnIndex);
    }

    public int getMaxXColumnIndex() {
        return maxXColumnIndex;
    }

    public GPKGRTreeIndexColumn getMaxXColumn() {
        return getColumn(maxXColumnIndex);
    }

    public int getMinYColumnIndex() {
        return minYColumnIndex;
    }

    public GPKGRTreeIndexColumn getMinYColumn() {
        return getColumn(minYColumnIndex);
    }

    public int getMaxYColumnIndex() {
        return maxYColumnIndex;
    }

    public GPKGRTreeIndexColumn getMaxYColumn() {
        return getColumn(maxYColumnIndex);
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
