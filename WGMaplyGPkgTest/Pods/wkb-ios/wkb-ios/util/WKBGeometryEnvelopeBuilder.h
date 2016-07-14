//
//  WKBGeometryEnvelopeBuilder.h
//  wkb-ios
//
//  Created by Brian Osborn on 6/1/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WKBGeometryEnvelope.h"
#import "WKBGeometry.h"

/**
 *  Builds an envelope from a Geometry
 */
@interface WKBGeometryEnvelopeBuilder : NSObject

/**
 *  Build geometry envelope with geometry
 *
 *  @param geometry geometry
 *
 *  @return geometry envelope
 */
+(WKBGeometryEnvelope *) buildEnvelopeWithGeometry: (WKBGeometry *) geometry;

/**
 *  Expand existing geometry envelope with a geometry
 *
 *  @param envelope geometry envelope
 *  @param geometry geometry
 */
+(void) buildEnvelope: (WKBGeometryEnvelope *) envelope andGeometry: (WKBGeometry *) geometry;

@end
