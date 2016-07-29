//
//  GPKGFeatureTileSource.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-08.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MaplyComponent.h"
#import "GPKGProgress.h"


#define GPKG_FEATURE_TILE_SOURCE_MAX_POINTS 4096
#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT 100
#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_LINESTRING 20
#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POLYGON 100

@class GPKGGeoPackage;

@interface GPKGFeatureTileSource : NSObject <MaplyPagingDelegate, GPKGProgress>

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName bounds:(NSDictionary *)bounds;

@property (nonatomic, readonly) MaplyCoordinate center;

@end
