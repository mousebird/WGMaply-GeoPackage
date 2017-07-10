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
@interface GPKGTileSource : NSObject <MaplyTileSource>

/** Set up with a GeoPackage and the table name we'd like to load as an image layer.
  */
- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName bounds:(NSDictionary *)bounds;

- (void)close;

/// Center of the layer
@property (nonatomic, readonly) MaplyCoordinate center;

@end
