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

@interface GPKGTileSource : NSObject <MaplyTileSource>

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName;

@end
