//
//  GPKGRTreeIndexDao.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-09-11.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GPKGRTreeIndexDao.h"

NSString * const GPKG_RT_COLUMN_GEOM_ID = @"id";
NSString * const GPKG_RT_COLUMN_MIN_X = @"minx";
NSString * const GPKG_RT_COLUMN_MAX_X = @"maxx";
NSString * const GPKG_RT_COLUMN_MIN_Y = @"miny";
NSString * const GPKG_RT_COLUMN_MAX_Y = @"maxy";

@implementation GPKGRTreeIndexDao

-(instancetype) initWithDatabase: (GPKGConnection *) database andFeatureDao: (GPKGFeatureDao *) featureDao {
    self = [super initWithDatabase:database];
    if(self != nil){
        self.tableName = [NSString stringWithFormat:@"rtree_%@_%@", featureDao.tableName, featureDao.getGeometryColumnName];
        
        self.idColumns = @[GPKG_RT_COLUMN_GEOM_ID];
        
        [self initializeColumnsWithQuery:true];
    }
    return self;
}

- (NSArray *) getColumnNames {
    GPKGResultSet * result = [self rawQuery:[NSString stringWithFormat:@"PRAGMA table_info(%@)", self.tableName]];
    NSMutableArray *columnNames = [NSMutableArray array];
    
    @try{
        while ([result moveToNext]){
            [columnNames addObject:[result getString:[result getColumnIndexWithName:@"name"]]];
        }
    }@finally{
        [result close];
    }
    return columnNames;
    
}

- (void) initializeColumnsWithQuery:(bool)query {
    if (query) {
        NSArray *columnNames = [self getColumnNames];
        if (columnNames.count == 0)
            return;
        self.columns = columnNames;
    } else {
        self.columns = @[GPKG_RT_COLUMN_GEOM_ID, GPKG_RT_COLUMN_MIN_X, GPKG_RT_COLUMN_MAX_X, GPKG_RT_COLUMN_MIN_Y, GPKG_RT_COLUMN_MAX_Y];
    }
    [self initializeColumnIndex];
}


-(NSObject *) createObject{
    return [[GPKGGeometryIndex alloc] init];
}

-(void) setValueInObject: (NSObject*) object withColumnIndex: (int) columnIndex withValue: (NSObject *) value{
    
    GPKGGeometryIndex *setObject = (GPKGGeometryIndex*) object;
    
    switch(columnIndex){
        case 0:
            setObject.geomId = (NSNumber *) value;
            break;
        case 1:
            setObject.minX = (NSDecimalNumber *) value;
            break;
        case 2:
            setObject.maxX = (NSDecimalNumber *) value;
            break;
        case 3:
            setObject.minY = (NSDecimalNumber *) value;
            break;
        case 4:
            setObject.maxY = (NSDecimalNumber *) value;
            break;
        default:
            [NSException raise:@"Illegal Column Index" format:@"Unsupported column index: %d", columnIndex];
            break;
    }
    
}

-(NSObject *) getValueFromObject: (NSObject*) object withColumnIndex: (int) columnIndex{
    
    NSObject * value = nil;
    
    GPKGGeometryIndex *getObject = (GPKGGeometryIndex*) object;
    
    switch(columnIndex){
        case 0:
            value = getObject.geomId;
            break;
        case 1:
            value = getObject.minX;
            break;
        case 2:
            value = getObject.maxX;
            break;
        case 3:
            value = getObject.minY;
            break;
        case 4:
            value = getObject.maxY;
            break;
        default:
            [NSException raise:@"Illegal Column Index" format:@"Unsupported column index: %d", columnIndex];
            break;
    }
    
    return value;
}


-(GPKGGeometryIndex *) populateWithGeomId:(NSNumber *)geomId andGeometryEnvelope:(WKBGeometryEnvelope *) envelope {
    
    GPKGGeometryIndex * geometryIndex = [[GPKGGeometryIndex alloc] init];
    [geometryIndex setGeomId:geomId];
    [geometryIndex setMinX:envelope.minX];
    [geometryIndex setMaxX:envelope.maxX];
    [geometryIndex setMinY:envelope.minY];
    [geometryIndex setMaxY:envelope.maxY];
    return geometryIndex;
    
}

-(GPKGBoundingBox *)getMinimalBoundingBox {
    NSString *queryString = [NSString stringWithFormat:@"SELECT MIN(minx) AS minx, MAX(maxx) AS maxx, MIN(miny) AS miny, MAX(maxy) AS maxy FROM %@;", self.tableName];
    
    GPKGResultSet *results;
    @try {
        results = [self rawQuery:queryString];
    } @catch (NSException *e) {
        return nil;
    }
    NSNumber *minX, *maxX, *minY, *maxY;
    @try {
        if ([results moveToNext]) {
            NSArray *result = [results getRow];
            minX = result[0];
            maxX = result[1];
            minY = result[2];
            maxY = result[3];
        }
    } @finally {
        [results close];
    }
    if (!minX || !maxX || !minY || !maxY)
        return nil;
    return [[GPKGBoundingBox alloc] initWithMinLongitudeDouble:minX.doubleValue andMaxLongitudeDouble:maxX.doubleValue andMinLatitudeDouble:minY.doubleValue andMaxLatitudeDouble:maxY.doubleValue];
    
}

@end
