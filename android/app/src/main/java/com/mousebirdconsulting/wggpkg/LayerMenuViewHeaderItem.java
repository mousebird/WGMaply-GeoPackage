package com.mousebirdconsulting.wggpkg;

/**
 * Created by rghosh on 2017-05-16.
 */

public class LayerMenuViewHeaderItem extends LayerMenuViewItem {

    private String headerText;

    public LayerMenuViewHeaderItem(String headerText) {
        this.headerText = headerText;
    }

    public String displayText() {
        return headerText;
    }
}
