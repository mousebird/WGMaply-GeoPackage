//
//  GPKGRTreeIndexDao.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-09-11.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "GPKGBaseDao.h"
#import "GPKGGeometryIndex.h"
#import "GPKGFeatureDao.h"

extern NSString * const GPKG_RT_COLUMN_GEOM_ID;
extern NSString * const GPKG_RT_COLUMN_MIN_X;
extern NSString * const GPKG_RT_COLUMN_MAX_X;
extern NSString * const GPKG_RT_COLUMN_MIN_Y;
extern NSString * const GPKG_RT_COLUMN_MAX_Y;


@interface GPKGRTreeIndexDao : GPKGBaseDao

-(instancetype) initWithDatabase: (GPKGConnection *) database andFeatureDao: (GPKGFeatureDao *) featureDao;

-(GPKGBoundingBox *)getMinimalBoundingBox;

@end
