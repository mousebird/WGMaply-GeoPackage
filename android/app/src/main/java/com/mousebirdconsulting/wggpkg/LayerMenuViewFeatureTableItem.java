package com.mousebirdconsulting.wggpkg;


/**
 * Created by rghosh on 2017-05-16.
 */

public class LayerMenuViewFeatureTableItem extends LayerMenuViewItem {

    private String featureTableName;

    public boolean enabled;

    public LayerMenuViewFeatureTableItem(String featureTableName) {
        this.featureTableName = featureTableName;
    }

    public String displayText() {
        return featureTableName;
    }

    public String getFeatureTableName() {
        return featureTableName;
    }

}
