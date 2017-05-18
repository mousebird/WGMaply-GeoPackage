package com.mousebirdconsulting.wggpkg;

import tellh.com.recyclertreeview_lib.LayoutItemType;

/**
 * Created by rghosh on 2017-05-16.
 */

public abstract class LayerMenuViewItem implements LayoutItemType {

    public abstract String displayText();

    @Override
    public int getLayoutId() {
        return R.layout.item;
    }
}
