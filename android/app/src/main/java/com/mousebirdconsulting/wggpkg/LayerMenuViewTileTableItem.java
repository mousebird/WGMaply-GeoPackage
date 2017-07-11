package com.mousebirdconsulting.wggpkg;


/**
 * Created by rghosh on 2017-05-16.
 */

public class LayerMenuViewTileTableItem extends LayerMenuViewItem {

    private String tileTableName;
    public boolean enabled;

    public LayerMenuViewTileTableItem(String tileTableName) {
        this.tileTableName = tileTableName;
    }

    public String displayText() {
        return tileTableName;
    }

    public String getTileTableName() {
        return tileTableName;
    }
}
