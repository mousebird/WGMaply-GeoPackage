package com.mousebirdconsulting.wggpkg;

import com.mousebird.maply.MaplyTileID;
import com.mousebird.maply.Mbr;
import com.mousebird.maply.QuadPagingLayer;
import com.mousebird.maply.QuadPagingLayer.PagingInterface;

/**
 * Created by rghosh on 2017-06-13.
 */

public class GPKGFeatureTileSource implements PagingInterface {

    int minZoom = 0;
    int maxZoom = 0;


    public GPKGFeatureTileSource(int inMinZoom, int inMaxZoom) {
        minZoom = inMinZoom;
        maxZoom = inMaxZoom;
    }

    /**
     * Min zoom level, probably 0.
     */
    @Override
    public int minZoom() {
        return minZoom;
    }

    /**
     * Max zoom level, typically 14 for vector tiles.
     */
    @Override
    public int maxZoom() {
        return maxZoom;
    }

    // The paging layer calls us here to start paging a tile
    @Override
    public void startFetchForTile(final QuadPagingLayer layer, final MaplyTileID tileID)
    {
        Mbr geoBbox =  layer.geoBoundsForTile(tileID);


        synchronized(this) {
            // TODO: initialize tile parser if necessary
        }




    }






    @Override
    public void tileDidUnload(MaplyTileID tileID)
    {
    }

    @Override
    public void clear()
    {
    }

}
