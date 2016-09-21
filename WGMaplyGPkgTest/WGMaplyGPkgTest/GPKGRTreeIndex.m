//
//  GPKGRTreeIndex.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-09-12.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "GPKGRTreeIndex.h"
#import "GPKGProperties.h"
#import "WKBGeometryEnvelopeBuilder.h"
#import "GPKGProjectionTransform.h"
#import "GPKGRTreeIndexDao.h"

NSString * const GPKG_EXTENSION_RTREE_INDEX_AUTHOR = @"gpkg";
NSString * const GPKG_EXTENSION_RTREE_INDEX_NAME_NO_AUTHOR = @"gpkg_rtree_index";
NSString * const GPKG_PROP_EXTENSION_RTREE_INDEX_DEFINITION = @"geopackage.extensions.gpkg_rtree_index";



@interface GPKGRTreeIndex ()

@property (nonatomic, strong) GPKGFeatureDao *featureDao;
@property (nonatomic, strong) NSString *extensionName;
@property (nonatomic, strong) GPKGRTreeIndexDao* rtreeIndexDao;
@property (nonatomic, strong) NSString *tableName;

@end

@implementation GPKGRTreeIndex

-(instancetype) initWithGeoPackage: (GPKGGeoPackage *) geoPackage andFeatureDao: (GPKGFeatureDao *) featureDao andTransform:(GPKGGeometryProjectionTransform *)transform {
    self = [super initWithGeoPackage:geoPackage];
    if(self != nil){
        self.featureDao = featureDao;
        self.extensionName = [GPKGExtensions buildExtensionNameWithAuthor:GPKG_EXTENSION_RTREE_INDEX_AUTHOR andExtensionName:GPKG_EXTENSION_RTREE_INDEX_NAME_NO_AUTHOR];
        
        self.tableName = [NSString stringWithFormat:@"rtree_%@_%@", self.featureDao.tableName, self.featureDao.getGeometryColumnName];
        
        self.rtreeIndexDao = [[GPKGRTreeIndexDao alloc] initWithDatabase:geoPackage.database andFeatureDao:featureDao];
        if (!self.rtreeIndexDao.columns) {
            [self setupRTreeIndexWithTransform:transform];
        }
        
        
    }
    return self;
}

- (void)setupRTreeIndexWithTransform:(GPKGGeometryProjectionTransform *)transform {
    NSString *createString = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE %@ USING rtree(id, minx, maxx, miny, maxy);", self.tableName];
    
    [_rtreeIndexDao.database exec:createString];
    [_rtreeIndexDao initializeColumnsWithQuery:false];
    
    [_rtreeIndexDao beginTransaction];
    GPKGResultSet *allResults = [self.featureDao queryForAll];
    while([allResults moveToNext]) {
        GPKGFeatureRow *featureRow = [self.featureDao getFeatureRow:allResults];
        GPKGGeometryData *geometryData = [featureRow getGeometry];
        
        if(geometryData != nil && !geometryData.empty){
            
            NSNumber *featureID = [featureRow getId];
            WKBGeometry * geometry = geometryData.geometry;
            
            geometry = [transform transformGeometry:geometry];
            WKBGeometryEnvelope *envelope = [WKBGeometryEnvelopeBuilder buildEnvelopeWithGeometry:geometry];
            
            if (envelope) {
                
                GPKGGeometryIndex *geometryIndex = [_rtreeIndexDao populateWithGeomId:featureID andGeometryEnvelope:envelope];
                [_rtreeIndexDao insert:geometryIndex];
            }
        }
    }
    [_rtreeIndexDao commitTransaction];
}

-(GPKGResultSet *) queryWithBoundingBox: (GPKGBoundingBox *) boundingBox {
    
    WKBGeometryEnvelope * envelope = [boundingBox buildEnvelope];
    GPKGResultSet * geometryResults = [self queryWithGeometryEnvelope:envelope];
    return geometryResults;
}

-(GPKGResultSet *) queryWithGeometryEnvelope: (WKBGeometryEnvelope *) envelope {
    
    NSMutableString * where = [NSMutableString string];
    NSMutableArray * whereArgs = [NSMutableArray array];
    
    [where appendString:[self.rtreeIndexDao buildWhereWithField:GPKG_RT_COLUMN_MIN_X andValue:envelope.maxX andOperation:@"<="]];
    [where appendString:@" and "];
    [where appendString:[self.rtreeIndexDao buildWhereWithField:GPKG_RT_COLUMN_MAX_X andValue:envelope.minX andOperation:@">="]];

    [where appendString:@" and "];
    [where appendString:[self.rtreeIndexDao buildWhereWithField:GPKG_RT_COLUMN_MIN_Y andValue:envelope.maxY andOperation:@"<="]];
    [where appendString:@" and "];
    [where appendString:[self.rtreeIndexDao buildWhereWithField:GPKG_RT_COLUMN_MAX_Y andValue:envelope.minY andOperation:@">="]];

    [whereArgs addObject:envelope.maxX];
    [whereArgs addObject:envelope.minX];
    [whereArgs addObject:envelope.maxY];
    [whereArgs addObject:envelope.minY];

    GPKGResultSet * results = [self.rtreeIndexDao queryWhere:where andWhereArgs:whereArgs];
    
    return results;
}

-(GPKGResultSet *) queryWithBoundingBox: (GPKGBoundingBox *) boundingBox andProjection: (GPKGProjection *) projection {
    
    GPKGBoundingBox * featureBoundingBox = [self getFeatureBoundingBoxWithBoundingBox:boundingBox andProjection:projection];
    GPKGResultSet * results = [self queryWithBoundingBox:featureBoundingBox];
    
    return results;
}

-(GPKGGeometryIndex *) getGeometryIndexWithResultSet: (GPKGResultSet *) resultSet{
    GPKGGeometryIndex * geometryIndex = (GPKGGeometryIndex *) [self.rtreeIndexDao getObject:resultSet];
    return geometryIndex;
}


-(GPKGFeatureRow *) getFeatureRowWithGeometryIndex: (GPKGGeometryIndex *) geometryIndex{
    GPKGFeatureRow * featureRow = (GPKGFeatureRow *)[self.featureDao queryForIdObject:geometryIndex.geomId];
    return featureRow;
}


-(GPKGFeatureRow *) getFeatureRowWithResultSet: (GPKGResultSet *) resultSet{
    GPKGGeometryIndex * geometryIndex = [self getGeometryIndexWithResultSet:resultSet];
    GPKGFeatureRow * featureRow = [self getFeatureRowWithGeometryIndex:geometryIndex];
    return featureRow;
}

-(GPKGBoundingBox *)getMinimalBoundingBox {
    return [self.rtreeIndexDao getMinimalBoundingBox];
}

-(GPKGBoundingBox *) getFeatureBoundingBoxWithBoundingBox: (GPKGBoundingBox *) boundingBox andProjection: (GPKGProjection *) projection{
    GPKGProjectionTransform * projectionTransform = [[GPKGProjectionTransform alloc] initWithFromProjection:projection andToProjection:self.featureDao.projection];
    GPKGBoundingBox * featureBoundingBox = [projectionTransform transformWithBoundingBox:boundingBox];
    return featureBoundingBox;
}


@end
