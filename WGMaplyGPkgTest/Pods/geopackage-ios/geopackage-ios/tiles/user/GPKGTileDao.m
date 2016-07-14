//
//  GPKGTileDao.m
//  geopackage-ios
//
//  Created by Brian Osborn on 6/5/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import "GPKGTileDao.h"
#import "GPKGTileRow.h"
#import "GPKGTileMatrix.h"
#import "GPKGTileMatrixSetDao.h"
#import "GPKGUtils.h"
#import "GPKGTileDaoUtils.h"
#import "GPKGProjectionTransform.h"
#import "GPKGProjectionFactory.h"
#import "GPKGProjectionConstants.h"
#import "GPKGTileBoundingBoxUtils.h"

@implementation GPKGTileDao

-(instancetype) initWithDatabase: (GPKGConnection *) database andTable: (GPKGTileTable *) table andTileMatrixSet: (GPKGTileMatrixSet *) tileMatrixSet andTileMatrices: (NSArray *) tileMatrices{
    self = [super initWithDatabase:database andTable:table];
    if(self != nil){
        self.database = database;
        self.tileMatrixSet = tileMatrixSet;
        self.tileMatrices = tileMatrices;
        
        NSInteger count = [tileMatrices count];
        NSMutableDictionary * tempZoomLevelToTileMatrix = [[NSMutableDictionary alloc] initWithCapacity:count];
        NSMutableArray * tempWidths = [[NSMutableArray alloc] initWithCapacity:count];
        NSMutableArray * tempHeights = [[NSMutableArray alloc] initWithCapacity:count];
        
        GPKGTileMatrixSetDao * dao =  [self getTileMatrixSetDao];
        self.projection = [dao getProjection:tileMatrixSet];
        
        // Set the min and max zoom levels
        if([tileMatrices count] == 0){
            self.minZoom = 0;
            self.maxZoom = 0;
        }else{
            self.minZoom = [((GPKGTileMatrix *)[tileMatrices objectAtIndex:0]).zoomLevel intValue];
            self.maxZoom = [((GPKGTileMatrix *)[tileMatrices objectAtIndex:(count-1)]).zoomLevel intValue];
        }
        
        // Populate the zoom level to tile matrix and the sorted tile widths and
        // heights
        for (int i = ((int)count)-1; i >= 0; i--) {
            GPKGTileMatrix * tileMatrix = (GPKGTileMatrix *) [tileMatrices objectAtIndex:i];
            [GPKGUtils setObject:tileMatrix forKey:tileMatrix.zoomLevel inDictionary:tempZoomLevelToTileMatrix];
            double width = [tileMatrix.pixelXSize doubleValue] * [tileMatrix.tileWidth intValue];
            double height = [tileMatrix.pixelYSize doubleValue] * [tileMatrix.tileHeight intValue];
            [GPKGUtils addObject:[[NSDecimalNumber alloc] initWithDouble:width] toArray:tempWidths];
            [GPKGUtils addObject:[[NSDecimalNumber alloc] initWithDouble:height] toArray:tempHeights];
        }
        
        if([dao getContents:tileMatrixSet] == nil){
            [NSException raise:@"No Contents" format:@"Tile Matrix Set %@ has null Contents", tileMatrixSet.tableName];
        }
        
        if([dao getSrs:tileMatrixSet] == nil){
            [NSException raise:@"No SRS" format:@"Tile Matrix Set %@ has null Spatial Reference System", tileMatrixSet.tableName];
        }
        
        self.zoomLevelToTileMatrix = tempZoomLevelToTileMatrix;
        self.widths = tempWidths;
        self.heights = tempHeights;
    }
    return self;
}

-(NSObject *) createObject{
    return [self newRow];
}

-(GPKGBoundingBox *) getBoundingBoxWithZoomLevel: (int) zoomLevel{
    GPKGBoundingBox * boundingBox = nil;
    GPKGTileMatrix * tileMatrix = [self getTileMatrixWithZoomLevel:zoomLevel];
    if(tileMatrix != nil){
        GPKGTileGrid * tileGrid = [self queryForTileGridWithZoomLevel:zoomLevel];
        if(tileGrid != nil){
            GPKGBoundingBox * matrixSetBoundingBox = [self getBoundingBox];
            boundingBox = [GPKGTileBoundingBoxUtils getBoundingBoxWithTotalBoundingBox:matrixSetBoundingBox andTileMatrix:tileMatrix andTileGrid:tileGrid];
        }
    }
    return boundingBox;
}

-(GPKGTileGrid *) getTileGridWithZoomLevel: (int) zoomLevel{
    GPKGTileGrid * tileGrid = nil;
    GPKGTileMatrix * tileMatrix = [self getTileMatrixWithZoomLevel:zoomLevel];
    if(tileMatrix != nil){
        tileGrid = [[GPKGTileGrid alloc] initWithMinX:0 andMaxX:[tileMatrix.matrixWidth intValue] - 1 andMinY:0 andMaxY:[tileMatrix.matrixHeight intValue] - 1];
    }
    return tileGrid;
}

-(GPKGTileTable *) getTileTable{
    return (GPKGTileTable *) self.table;
}

-(GPKGTileRow *) getTileRow: (GPKGResultSet *) results{
    return (GPKGTileRow *) [self getRow:results];
}

-(GPKGUserRow *) newRowWithColumnTypes: (NSArray *) columnTypes andValues: (NSMutableArray *) values{
    return [[GPKGTileRow alloc] initWithTileTable:[self getTileTable] andColumnTypes:columnTypes andValues:values];
}

-(GPKGTileRow *) newRow{
    return [[GPKGTileRow alloc] initWithTileTable:(GPKGTileTable *)self.table];
}

-(void) adjustTileMatrixLengths{
    [GPKGTileDaoUtils adjustTileMatrixLengthsWithTileMatrixSet:self.tileMatrixSet andTileMatrices:self.tileMatrices];
}

-(GPKGTileMatrix *) getTileMatrixWithZoomLevel: (int) zoomLevel{
    return (GPKGTileMatrix *)[GPKGUtils objectForKey:[NSNumber numberWithInt:zoomLevel] inDictionary:self.zoomLevelToTileMatrix];
}

-(GPKGTileRow *) queryForTileWithColumn: (int) column andRow: (int) row andZoomLevel: (int) zoomLevel{
    
    GPKGColumnValues * fieldValues = [[GPKGColumnValues alloc] init];
    [fieldValues addColumn:GPKG_TT_COLUMN_TILE_COLUMN withValue:[NSNumber numberWithInt:column]];
    [fieldValues addColumn:GPKG_TT_COLUMN_TILE_ROW withValue:[NSNumber numberWithInt:row]];
    [fieldValues addColumn:GPKG_TT_COLUMN_ZOOM_LEVEL withValue:[NSNumber numberWithInt:zoomLevel]];
    
    GPKGResultSet * results = [self queryForFieldValues:fieldValues];
    GPKGTileRow * tileRow = nil;
    @try{
        if([results moveToNext]){
            tileRow = [self getTileRow:results];
        }
    }@finally{
        [results close];
    }
    
    return tileRow;
}

-(GPKGResultSet *) queryforTileWithZoomLevel: (int) zoomLevel{
    return [self queryForEqWithField:GPKG_TT_COLUMN_ZOOM_LEVEL andValue:[NSNumber numberWithInt:zoomLevel]];
}

-(GPKGResultSet *) queryForTileDescending: (int) zoomLevel{
    return [self queryForEqWithField:GPKG_TT_COLUMN_ZOOM_LEVEL andValue:[NSNumber numberWithInt:zoomLevel] andGroupBy:nil andHaving:nil andOrderBy:[NSString stringWithFormat:@"%@ DESC, %@ DESC", GPKG_TT_COLUMN_TILE_COLUMN, GPKG_TT_COLUMN_TILE_ROW]];
}

-(GPKGResultSet *) queryForTilesInColumn: (int) column andZoomLevel: (int) zoomLevel{
    
    GPKGColumnValues * fieldValues = [[GPKGColumnValues alloc] init];
    [fieldValues addColumn:GPKG_TT_COLUMN_TILE_COLUMN withValue:[NSNumber numberWithInt:column]];
    [fieldValues addColumn:GPKG_TT_COLUMN_ZOOM_LEVEL withValue:[NSNumber numberWithInt:zoomLevel]];
    
    return [self queryForFieldValues:fieldValues];
}

-(GPKGResultSet *) queryForTilesInRow: (int) row andZoomLevel: (int) zoomLevel{
    GPKGColumnValues * fieldValues = [[GPKGColumnValues alloc] init];
    [fieldValues addColumn:GPKG_TT_COLUMN_TILE_ROW withValue:[NSNumber numberWithInt:row]];
    [fieldValues addColumn:GPKG_TT_COLUMN_ZOOM_LEVEL withValue:[NSNumber numberWithInt:zoomLevel]];
    
    return [self queryForFieldValues:fieldValues];
}

-(NSNumber *) getZoomLevelWithLength: (double) length{
    return [GPKGTileDaoUtils getZoomLevelWithWidths:self.widths andHeights:self.heights andTileMatrices:self.tileMatrices andLength:length];
}

-(GPKGResultSet *) queryByTileGrid: (GPKGTileGrid *) tileGrid andZoomLevel: (int) zoomLevel{
    GPKGResultSet * results = nil;
    
    if(tileGrid != nil){
        
        NSMutableString * where = [[NSMutableString alloc] init];
        
        NSNumber * zoom = [NSNumber numberWithInt:zoomLevel];
        NSNumber * minX = [NSNumber numberWithInt:tileGrid.minX];
        NSNumber * maxX = [NSNumber numberWithInt:tileGrid.maxX];
        NSNumber * minY = [NSNumber numberWithInt:tileGrid.minY];
        NSNumber * maxY = [NSNumber numberWithInt:tileGrid.maxY];
        
        [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_ZOOM_LEVEL andValue:zoom]];
        
        [where appendString:@" and "];
        [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_TILE_COLUMN andValue:minX andOperation:@">="]];
        
        [where appendString:@" and "];
        [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_TILE_COLUMN andValue:maxX andOperation:@"<="]];
        
        [where appendString:@" and "];
        [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_TILE_ROW andValue:minY andOperation:@">="]];
        
        [where appendString:@" and "];
        [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_TILE_ROW andValue:maxY andOperation:@"<="]];
        
        NSArray * whereArgs = [self buildWhereArgsWithValueArray:[[NSArray alloc] initWithObjects:zoom,
                               minX,
                               maxX,
                               minY,
                               maxY, nil]];
        
        results = [self queryWhere:where andWhereArgs:whereArgs];
    }
    return results;
}

-(GPKGTileGrid *) queryForTileGridWithZoomLevel: (int) zoomLevel{
    
    NSNumber * zoomLevelNumber = [NSNumber numberWithInt:zoomLevel];
    NSString * where = [self buildWhereWithField:GPKG_TT_COLUMN_ZOOM_LEVEL andValue:zoomLevelNumber];
    NSArray * whereArgs = [self buildWhereArgsWithValue:zoomLevelNumber];
    
    NSNumber * minX = [self minOfColumn:GPKG_TT_COLUMN_TILE_COLUMN andWhere:where andWhereArgs:whereArgs];
    NSNumber * maxX = [self maxOfColumn:GPKG_TT_COLUMN_TILE_COLUMN andWhere:where andWhereArgs:whereArgs];
    NSNumber * minY = [self minOfColumn:GPKG_TT_COLUMN_TILE_ROW andWhere:where andWhereArgs:whereArgs];
    NSNumber * maxY = [self maxOfColumn:GPKG_TT_COLUMN_TILE_ROW andWhere:where andWhereArgs:whereArgs];
    
    GPKGTileGrid * tileGrid = nil;
    if(minX != nil && maxX != nil && minY != nil && maxY != nil){
        tileGrid = [[GPKGTileGrid alloc] initWithMinX:[minX intValue] andMaxX:[maxX intValue] andMinY:[minY intValue] andMaxY:[maxY intValue]];
    }
    
    return tileGrid;
}

-(int) deleteTileWithColumn: (int) column andRow: (int) row andZoomLevel: (int) zoomLevel{
    
    NSMutableString * where = [[NSMutableString alloc] init];
    
    NSNumber * zoom = [NSNumber numberWithInt:zoomLevel];
    NSNumber * columnNumber = [NSNumber numberWithInt:column];
    NSNumber * rowNumber = [NSNumber numberWithInt:row];
    
    [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_ZOOM_LEVEL andValue:zoom]];
    
    [where appendString:@" and "];
    [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_TILE_COLUMN andValue:columnNumber]];
    
    [where appendString:@" and "];
    [where appendString:[self buildWhereWithField:GPKG_TT_COLUMN_TILE_ROW andValue:rowNumber]];
    
    NSArray * whereArgs = [self buildWhereArgsWithValueArray:[[NSArray alloc] initWithObjects:zoom,
                           columnNumber,
                           rowNumber, nil]];
    int deleted = [self deleteWhere:where andWhereArgs:whereArgs];
    
    return deleted;
}

-(int) countWithZoomLevel: (int) zoomLevel{
    NSNumber * zoom = [NSNumber numberWithInt:zoomLevel];
    NSString * where = [self buildWhereWithField:GPKG_TT_COLUMN_ZOOM_LEVEL andValue:zoom];
    NSArray * whereArgs = [self buildWhereArgsWithValue:zoom];
    return [self countWhere:where andWhereArgs:whereArgs];
}

-(double) getMaxLength{
    return [GPKGTileDaoUtils getMaxLengthWithWidths:self.widths andHeights:self.heights];
}

-(double) getMinLength{
    return [GPKGTileDaoUtils getMinLengthWithWidths:self.widths andHeights:self.heights];
}

-(BOOL) isStandardWebMercatorFormat{
    
    // Convert the bounding box to wgs84
    GPKGBoundingBox * boundingBox = [self.tileMatrixSet getBoundingBox];
    GPKGProjectionTransform * transform = [[GPKGProjectionTransform alloc] initWithFromProjection:self.projection andToEpsg:PROJ_EPSG_WORLD_GEODETIC_SYSTEM];
    GPKGBoundingBox * wgs84BoundingBox = [transform transformWithBoundingBox:boundingBox];

    BOOL isFormat = false;
    
    // Verify the bounds are the entire world
    if([wgs84BoundingBox.minLatitude doubleValue] <= PROJ_WEB_MERCATOR_MIN_LAT_RANGE
       && [wgs84BoundingBox.maxLatitude doubleValue] <= PROJ_WEB_MERCATOR_MAX_LAT_RANGE
       && [wgs84BoundingBox.minLongitude doubleValue] <= -180.0
       && [wgs84BoundingBox.maxLongitude doubleValue] >= 180.0){
        
        isFormat = true;
        
        for(GPKGTileMatrix * tileMatrix in self.tileMatrices){
            int zoomLevel = [tileMatrix.zoomLevel intValue];
            int tilesPerSide = [GPKGTileBoundingBoxUtils tilesPerSideWithZoom:zoomLevel];
            if([tileMatrix.matrixWidth intValue] != tilesPerSide
               || [tileMatrix.matrixHeight intValue] != tilesPerSide){
                isFormat = false;
                break;
            }
        }
    }
    
    return isFormat;
}

-(GPKGTileMatrixSetDao *) getTileMatrixSetDao{
    return [[GPKGTileMatrixSetDao alloc] initWithDatabase:self.database];
}

-(GPKGBoundingBox *) getBoundingBox{
    return [self.tileMatrixSet getBoundingBox];
}

@end
