//
//  WKBMultiPolygon.m
//  wkb-ios
//
//  Created by Brian Osborn on 6/2/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import "WKBMultiPolygon.h"

@implementation WKBMultiPolygon

-(instancetype) initWithHasZ: (BOOL) hasZ andHasM: (BOOL) hasM{
    self = [super initWithType:WKB_MULTIPOLYGON andHasZ:hasZ andHasM:hasM];
    return self;
}

-(NSMutableArray *) getPolygons{
    return [self geometries];
}

-(void) setPolygons: (NSMutableArray *) polygons{
    [self setGeometries:polygons];
}

-(void) addPolygon: (WKBPolygon *) polygon{
    [self addGeometry:polygon];
}

-(NSNumber *) numPolygons{
    return [self numGeometries];
}

@end
