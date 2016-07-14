//
//  GPKGFeatureTileSource.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-08.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "GPKGFeatureTileSource.h"
#import "GPKGFeatureDao.h"

@implementation GPKGFeatureTileSource {
    GPKGGeoPackage *_geoPackage;
    GPKGFeatureDao *_featureDao;
}

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage {
    self = [super init];
    if (self) {
        _geoPackage = geoPackage;
//        _featureDao = [[GPKGFeatureDao alloc] initWithDatabase:<#(GPKGConnection *)#> andTable:<#(GPKGFeatureTable *)#> andGeometryColumns:<#(GPKGGeometryColumns *)#> andMetadataDb:<#(GPKGMetadataDb *)#>]
    }
    return self;
}
@end
