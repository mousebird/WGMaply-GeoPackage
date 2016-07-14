//
//  WKBPoint.h
//  wkb-ios
//
//  Created by Brian Osborn on 6/2/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import "WKBGeometry.h"

/**
 * A single location in space. Each point has an X and Y coordinate. A point MAY
 * optionally also have a Z and/or an M value.
 */
@interface WKBPoint : WKBGeometry

/**
 *  X coordinate
 */
@property (nonatomic, strong) NSDecimalNumber * x;

/**
 *  Y coordinate
 */
@property (nonatomic, strong) NSDecimalNumber * y;

/**
 *  Z coordinate
 */
@property (nonatomic, strong) NSDecimalNumber * z;

/**
 *  M coordinate
 */
@property (nonatomic, strong) NSDecimalNumber * m;

/**
 *  Initialize
 *
 *  @param x x coordinate
 *  @param y y coordinate
 *
 *  @return new point
 */
-(instancetype) initWithX: (NSDecimalNumber *) x andY: (NSDecimalNumber *) y;

/**
 *  Initialize
 *
 *  @param hasZ has z coordinate
 *  @param hasM has m coordinate
 *  @param x    x coordinate
 *  @param y    y coordinate
 *
 *  @return new point
 */
-(instancetype) initWithHasZ: (BOOL) hasZ andHasM: (BOOL) hasM andX: (NSDecimalNumber *) x andY: (NSDecimalNumber *) y;

@end
