//
//  GPKGTileSource.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-07.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MaplyComponent.h"

@class GPKGGeoPackage;

/**
    A tile source implementation that works with a GeoPackage tile layer.
  */
@interface GPKGTileFetcher : MaplySimpleTileFetcher

/** Set up with a GeoPackage and the table name we'd like to load as an image layer.
  */
- (id _Nullable )initWithGeoPackage:(GPKGGeoPackage *_Nonnull)geoPackage tableName:(NSString *_Nonnull)tableName bounds:(NSDictionary *_Nullable)bounds;

/// TileInfo objected needed by a QuadImageLoader
- (nullable NSObject<MaplyTileInfoNew> *)tileInfo;

// Min zoom read from file
- (int)minZoom;

// Max zoom read from file
- (int)maxZoom;

// Close the GeoPackage table and so forth
- (void)shutdown;

/// Center of the layer
@property (nonatomic, readonly) MaplyCoordinate center;

// Coordinate system of the data
- (MaplyCoordinateSystem * __nonnull)coordSys;

@end
