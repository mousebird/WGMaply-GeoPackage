//
//  GPKGRTreeIndexResults.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-09-13.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "GPKGRTreeIndexResults.h"

@interface GPKGRTreeIndexResults ()

@property (nonatomic, strong) GPKGRTreeIndex *rtreeIndex;

@end


@implementation GPKGRTreeIndexResults

-(instancetype) initWithRTreeIndex: (GPKGRTreeIndex *) rtreeIndex andResults: (GPKGResultSet *) results {
    self = [super initWithResults:results];
    if(self != nil){
        self.rtreeIndex = rtreeIndex;
    }
    return self;
}

-(GPKGFeatureRow *) getFeatureRow{
    return [self.rtreeIndex getFeatureRowWithResultSet:[self getResults]];
}

@end
