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
#import "MapboxVectorTiles.h"


//#define GPKG_FEATURE_TILE_SOURCE_MAX_POINTS 4096
//#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT 100
//#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_LINESTRING 20
//#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POLYGON 100

#define GPKG_FEATURE_TILE_SOURCE_MAX_POINTS 4096
#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT 20000
#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_LINESTRING 10000
#define GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POLYGON 14000
#define GPKG_FEATURE_TILE_SOURCE_TARGET_TILE_COUNT 128

@class GPKGGeoPackage;
@class GPKGRTreeIndex;
@class GPKGGeometryProjectionTransform;

@interface GPKGFeatureTileStyler : NSObject

- (int)buildObjectsWithTileID:(MaplyTileID)tileID andGeoBBox:(MaplyBoundingBox)geoBbox andGeoBBoxDeg:(MaplyBoundingBox)geoBboxDeg andCompObjs:(NSMutableArray * __nonnull)compObjs;

/// @brief The styling delegate turns vector data into visible objects in the toolkit
@property (nonatomic, strong, nonnull) NSObject<MaplyVectorStyleDelegate> *styleDelegate;

/// @brief Maply view controller we're adding this data to
@property (nonatomic, weak, nullable) MaplyBaseViewController *viewC;


@end




@interface GPKGFeatureTileSource : NSObject <MaplyPagingDelegate, GPKGProgress>

- (id __nullable)initWithGeoPackage:(GPKGGeoPackage * __nonnull)geoPackage tableName:(NSString * __nonnull)tableName bounds:(NSDictionary * __nonnull)bounds sldURL:(NSURL * __nonnull)sldURL minZoom:(unsigned int)minZoom maxZoom:(unsigned int)maxZoom;
- (void)close;

@property (nonatomic, readonly) MaplyCoordinate center;

@end
