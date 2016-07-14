//
//  GPKGFeatureTileSource.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-08.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MaplyComponent.h"

@class GPKGGeoPackage;

@interface GPKGFeatureTileSource : NSObject <MaplyPagingDelegate>

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage;

@end
