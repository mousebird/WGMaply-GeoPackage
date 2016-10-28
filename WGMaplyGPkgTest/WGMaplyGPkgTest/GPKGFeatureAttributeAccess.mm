//
//  GPKGFeatureAttributeAccess.mm
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-10-25.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//


#import "GPKGFeatureAttributeAccess.h"
#import "MaplyVectorObject.h"
#import "MaplyVectorObject_private.h"

@implementation GPKGFeatureAttributeAccess

+ (void) setAttributes:(NSMutableDictionary *)attributes forVectorObject:(MaplyVectorObject *)vectorObject {
    vectorObject.attributes = attributes;
}
@end
