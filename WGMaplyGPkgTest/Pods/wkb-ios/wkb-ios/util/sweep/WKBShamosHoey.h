//
//  WKBShamosHoey.h
//  wkb-ios
//
//  Created by Brian Osborn on 1/12/18.
//  Copyright © 2018 NGA. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WKBPolygon.h"
#import "WKBPoint.h"
#import "WKBLineString.h"

/**
 * Shamos-Hoey simple polygon detection
 *
 * Based upon C++ implementation:
 * http://geomalgorithms.com/a09-_intersect-3.html
 *
 * C++ implementation license:
 *
 * Copyright 2001 softSurfer, 2012 Dan Sunday This code may be freely used and
 * modified for any purpose providing that this copyright notice is included
 * with it. SoftSurfer makes no warranty for this code, and cannot be held
 * liable for any real or imagined damage resulting from its use. Users of this
 * code must verify correctness for their application.
 */
@interface WKBShamosHoey : NSObject

/**
 * Determine if the polygon is simple
 *
 * @param polygon
 *            polygon
 * @return true if simple, false if intersects
 */
+(BOOL) simplePolygon: (WKBPolygon *) polygon;

/**
 * Determine if the polygon points are simple
 *
 * @param points
 *            polygon as points
 * @return true if simple, false if intersects
 */
+(BOOL) simplePolygonPoints: (NSArray<WKBPoint *> *) points;

/**
 * Determine if the polygon point rings are simple
 *
 * @param pointRings
 *            polygon point rings
 * @return true if simple, false if intersects
 */
+(BOOL) simplePolygonRingPoints: (NSArray<NSArray<WKBPoint *>*> *) pointRings;

/**
 * Determine if the polygon line string ring is simple
 *
 * @param ring
 *            polygon ring as a line string
 * @return true if simple, false if intersects
 */
+(BOOL) simplePolygonRing: (WKBLineString *) ring;

/**
 * Determine if the polygon rings are simple
 *
 * @param rings
 *            polygon rings
 * @return true if simple, false if intersects
 */
+(BOOL) simplePolygonRings: (NSArray<WKBLineString *> *) rings;

@end
