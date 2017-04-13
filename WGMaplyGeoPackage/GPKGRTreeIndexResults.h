//
//  GPKGRTreeIndexResults.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-09-13.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPKGRTreeIndex.h"
#import "GPKGFeatureIndexResults.h"

@interface GPKGRTreeIndexResults : GPKGFeatureIndexResults

-(instancetype) initWithRTreeIndex: (GPKGRTreeIndex *) rtreeIndex andResults: (GPKGResultSet *) results;


@end
