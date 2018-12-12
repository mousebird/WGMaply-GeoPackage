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

-(instancetype) initWithGeoPackage: (GPKGGeoPackage *) geoPackage andFeatureDao: (GPKGFeatureDao *) featureDao {
    self = [super initWithGeoPackage:geoPackage];
    if(self != nil){
        if (featureDao.idColumns.count < 1) {
            NSLog(@"Feature table breaks GeoPackage requirement for a primary key (2.1.6.1.1, Requirement 29).");
            return nil;
        }
        self.featureDao = featureDao;
        self.extensionName = [GPKGExtensions buildExtensionNameWithAuthor:GPKG_EXTENSION_RTREE_INDEX_AUTHOR andExtensionName:GPKG_EXTENSION_RTREE_INDEX_NAME_NO_AUTHOR];
        
        self.tableName = [NSString stringWithFormat:@"rtree_%@_%@", self.featureDao.tableName, self.featureDao.getGeometryColumnName];
        
    }
    return self;
}

- (void)indexTable {
    self.rtreeIndexDao = [[GPKGRTreeIndexDao alloc] initWithDatabase:self.geoPackage.database andFeatureDao:self.featureDao];
    
    if (!self.rtreeIndexDao.columns || (self.featureDao.count != self.rtreeIndexDao.count)) {
        GPKGSpatialReferenceSystemDao * srsDao = [self.geoPackage getSpatialReferenceSystemDao];
        GPKGSpatialReferenceSystem * srs = (GPKGSpatialReferenceSystem *)[srsDao queryForIdObject:self.featureDao.projection.epsg];
        
        GPKGProjectionTransform *projTransform = [[GPKGProjectionTransform alloc] initWithFromSrs:srs andToEpsg:4326];
        GPKGGeometryProjectionTransform *transform = [[GPKGGeometryProjectionTransform alloc] initWithProjectionTransform:projTransform];
        
        [self setupRTreeIndexWithTransform:transform createVTable:(self.rtreeIndexDao.columns == nil)];
    } else {
        __strong NSObject<GPKGProgress> *progress = self.progress;
        if (progress)
            [progress completed];
    }
}

- (void)setupRTreeIndexWithTransform:(GPKGGeometryProjectionTransform *)transform createVTable:(bool)createVTable {
    NSString *createString = [NSString stringWithFormat:@"CREATE VIRTUAL TABLE %@ USING rtree(id, minx, maxx, miny, maxy);", self.tableName];
    
    bool success = false;
    __strong NSObject<GPKGProgress> *progress = self.progress;
    NSString *errorString = @"";
    GPKGResultSet *allResults;
    @try {
        if (createVTable) {
            [_rtreeIndexDao beginTransaction];
            [_rtreeIndexDao.database exec:createString];
            [_rtreeIndexDao commitTransaction];
        }
        [_rtreeIndexDao initializeColumnsWithQuery:false];
        allResults = [self.featureDao queryWhere:nil andWhereArgs:nil andGroupBy:nil andHaving:nil andOrderBy:self.featureDao.idColumns[0]];
        
        int featureRowIdx = 0;
        int featureRowsSkip = self.rtreeIndexDao.count;
        [_rtreeIndexDao beginTransaction];
        while((progress == nil || [progress isActive]) && [allResults moveToNext]) {
            if (featureRowIdx < featureRowsSkip) {
                featureRowIdx++;
                continue;
            }
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
            if(progress != nil){
                [progress addProgress:1];
            }
            featureRowIdx++;
        }
        [_rtreeIndexDao commitTransaction];
        [allResults close];
        allResults = nil;
        if(progress == nil || [progress isActive]) {
            success = true;
            if (progress)
                [progress completed];
        } else {
            errorString = @"Indexing finished but delegate not active.";
        }
    } @catch (NSException *e) {
        @try {
            [_rtreeIndexDao commitTransaction];
        } @finally {
        }
        @try {
            if (allResults) {
                [allResults close];
                allResults = nil;
            }
        } @finally {
        }
        errorString = e.reason;
    } @finally {
        if (!success) {
            self.featureDao = nil;
            self.geoPackage = nil;
            if (progress)
                [progress failureWithError:errorString];
        }
    }
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

-(GPKGFeatureRow *) getFeatureRowWithResultSet: (GPKGResultSet *)resultSet withFilterInfo:(NSDictionary *) filterInfo {
    
    GPKGGeometryIndex * geometryIndex = [self getGeometryIndexWithResultSet:resultSet];
    
    NSMutableString * where = [NSMutableString string];
    NSMutableArray * whereArgs = [NSMutableArray array];
    
    [where appendString:[self.featureDao buildPkWhereWithValue:geometryIndex.geomId]];
    
    [whereArgs addObject:geometryIndex.geomId];
    
    if(filterInfo)
    {
        for (NSString * key in filterInfo.allKeys) {
            
            [where appendString:@" and "];
            [where appendString:[self.rtreeIndexDao buildWhereWithField:key andValue:[filterInfo objectForKey:key] andOperation:@"=="]];
            
            [whereArgs addObject:[filterInfo objectForKey:key]];
        }
    }
    
    GPKGResultSet * resultSetObj = [self.featureDao queryWhere:where andWhereArgs:whereArgs andGroupBy:nil andHaving:nil andOrderBy:nil andLimit:nil];
    GPKGFeatureRow * featureRow = (GPKGFeatureRow*)[self.featureDao getFirstObject:resultSetObj];
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
