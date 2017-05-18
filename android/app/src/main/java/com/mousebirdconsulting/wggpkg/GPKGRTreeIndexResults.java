package com.mousebirdconsulting.wggpkg;

import java.util.Iterator;

import mil.nga.geopackage.extension.index.FeatureTableIndex;
import mil.nga.geopackage.features.index.FeatureIndexResults;
import mil.nga.geopackage.features.user.FeatureRow;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndexResults implements FeatureIndexResults {

    GPKGRTreeIndex rtreeIndex;

    public GPKGRTreeIndexResults(GPKGRTreeIndex rtreeIndex) {

        this.rtreeIndex = rtreeIndex;
    }

    @Override
    public Iterator<FeatureRow> iterator() {
        Iterator<FeatureRow> iterator = new Iterator<FeatureRow>() {

            @Override
            public boolean hasNext() {
                // TODO: implement this
                return false;
            }

            @Override
            public FeatureRow next() {
                // TODO: implement this
                return null;
            }

            @Override
            public void remove() {
                // TODO: implement this
            }

        };
        return iterator;
    }


    @Override
    public long count() {
        // TODO: implement this
        return 0;
    }

    @Override
    public void close() {
        // TODO: implement this
    }

}
