package com.mousebirdconsulting.wggpkg;

import mil.nga.geopackage.GeoPackageCore;
import mil.nga.geopackage.extension.BaseExtension;
import mil.nga.geopackage.features.user.FeatureDao;

/**
 * Created by rghosh on 2017-05-18.
 */

public class GPKGRTreeIndex extends BaseExtension {

    /**
     * Feature DAO
     */
    private final FeatureDao featureDao;


    public GPKGRTreeIndex(GeoPackageCore geoPackage, FeatureDao featureDao) {
        super(geoPackage);
        this.featureDao = featureDao;
    }
}
