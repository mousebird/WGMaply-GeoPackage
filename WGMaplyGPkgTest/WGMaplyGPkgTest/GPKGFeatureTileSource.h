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

@class GPKGGeoPackage;

@interface GPKGFeatureTileSource : NSObject <MaplyPagingDelegate, GPKGProgress>

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName bounds:(NSDictionary *)bounds;

@end
