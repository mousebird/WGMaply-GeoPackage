//
//  GPKGProjectionFactory.h
//  geopackage-ios
//
//  Created by Brian Osborn on 5/21/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPKGProjection.h"
#import "GPKGSpatialReferenceSystem.h"

/**
 *  Projection factory for coordinate projections and transformations
 */
@interface GPKGProjectionFactory : NSObject

/**
 *  Get the projection with the epsg number
 *
 *  @param epsg epsg code
 *
 *  @return projection
 */
+(GPKGProjection *) getProjectionWithNumber: (NSNumber *) epsg;

/**
 *  Get the projection with the epsg int
 *
 *  @param epsg epsg code
 *
 *  @return projection
 */
+(GPKGProjection *) getProjectionWithInt: (int) epsg;

/**
 *  Get the projection for the Spatial Reference System
 *
 *  @param srs spatial reference system
 *
 *  @return projection
 */
+(GPKGProjection *) getProjectionWithSrs: (GPKGSpatialReferenceSystem *) srs;

@end
