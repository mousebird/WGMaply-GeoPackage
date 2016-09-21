//
//  GPKGRTreeIndex.h
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-09-12.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPKGGeoPackage.h"
#import "GPKGFeatureDao.h"
#import "GPKGProgress.h"
#import "GPKGBaseExtension.h"
#import "GPKGGeometryProjectionTransform.h"


extern NSString * const GPKG_EXTENSION_RTREE_INDEX_AUTHOR;
extern NSString * const GPKG_EXTENSION_RTREE_INDEX_NAME_NO_AUTHOR;
extern NSString * const GPKG_PROP_EXTENSION_RTREE_INDEX_DEFINITION;


@interface GPKGRTreeIndex : GPKGBaseExtension

-(instancetype) initWithGeoPackage: (GPKGGeoPackage *) geoPackage andFeatureDao: (GPKGFeatureDao *) featureDao andTransform:(GPKGGeometryProjectionTransform *)transform;

-(GPKGResultSet *) queryWithBoundingBox: (GPKGBoundingBox *) boundingBox;
-(GPKGResultSet *) queryWithGeometryEnvelope: (WKBGeometryEnvelope *) envelope;
-(GPKGResultSet *) queryWithBoundingBox: (GPKGBoundingBox *) boundingBox andProjection: (GPKGProjection *) projection;

-(GPKGFeatureRow *) getFeatureRowWithResultSet: (GPKGResultSet *) resultSet;

-(GPKGBoundingBox *)getMinimalBoundingBox;

@end
