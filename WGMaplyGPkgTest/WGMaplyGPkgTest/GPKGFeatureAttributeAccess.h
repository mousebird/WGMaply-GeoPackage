//
//  GPKGFeatureAttributeAccess.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-10-25.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MaplyVectorObject;

/** @brief This class exists to allow GPKGFeatureTileSource (which must be in Objective-C to compile) to access functionality that must be in Objective-C++ to compile.
 */
@interface GPKGFeatureAttributeAccess : NSObject

+ (void) setAttributes:(NSMutableDictionary *)attributes forVectorObject:(MaplyVectorObject *)vectorObject;

@end
