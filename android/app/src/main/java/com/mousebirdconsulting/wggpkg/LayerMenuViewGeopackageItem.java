package com.mousebirdconsulting.wggpkg;



/**
 * Created by rghosh on 2017-05-16.
 */

public class LayerMenuViewGeopackageItem extends LayerMenuViewItem {

    private String filename;
    private boolean imported;


    private boolean loaded;


    public LayerMenuViewGeopackageItem(String filename) {
        this.filename = filename;
    }

    public String getFilename() {
        return filename;
    }

    public boolean isImported() {
        return imported;
    }

    public void setImported(boolean imported) {
        this.imported = imported;
    }

    public boolean isLoaded() {
        return loaded;
    }

    public void setLoaded(boolean loaded) {
        this.loaded = loaded;
    }




    public String displayText() {
        return filename;
    }
}
