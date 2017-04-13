//
//  GPKGFeatureTileSource.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-08.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "GPKGFeatureTileSource.h"
#import "GPKGFeatureDao.h"
#import "GPKGGeoPackageFactory.h"
#import "GPKGFeatureIndexManager.h"
#import "GPKGMapShapeConverter.h"
#import "WKBGeometryJSONCompatible.h"
#import "GPKGProjectionRetriever.h"
#import "GPKGProjectionFactory.h"
#import "GPKGProjectionTransform.h"
#import "GPKGGeometryProjectionTransform.h"
#import "GPKGRTreeIndex.h"
#import "GPKGRTreeIndexResults.h"
#import "MapboxVectorTiles.h"
#import "SLDStyleSet.h"
#import "GPKGFeatureAttributeAccess.h"

@implementation GPKGFeatureTileStyler {
    GPKGRTreeIndex *_rtreeIndex;
    int _targetLevel;
    int _maxZoom;
    UIImage *_markerImage;
    GPKGGeometryProjectionTransform *_geomProjTransform;
}

- (nonnull instancetype)initWithStyle:(NSObject<MaplyVectorStyleDelegate> *__nonnull)styleDelegate viewC:(MaplyBaseViewController *__nonnull)viewC targetLevel:(int)targetLevel maxZoom:(int)maxZoom markerImage:(UIImage *)markerImage rtreeIndex:(GPKGRTreeIndex *__nonnull)rtreeIndex geomProjTransform:(GPKGGeometryProjectionTransform *__nonnull)geomProjTransform {
    
    self = [super init];
    if (self) {
        _styleDelegate = styleDelegate;
        _viewC = viewC;
        _maxZoom = maxZoom;
        _targetLevel = targetLevel;
        _markerImage = markerImage;
        _rtreeIndex = rtreeIndex;
        _geomProjTransform = geomProjTransform;
    }
    return self;
}



- (int)buildObjectsWithTileID:(MaplyTileID)tileID andGeoBBox:(MaplyBoundingBox)geoBbox andGeoBBoxDeg:(MaplyBoundingBox)geoBboxDeg andCompObjs:(NSMutableArray *)compObjs {
    
    if (tileID.level > _targetLevel)
        return 0;
    
    NSMutableDictionary *featureStyles = [NSMutableDictionary new];
    
    GPKGResultSet * geometryIndexResults;
    while (!geometryIndexResults) {
        @try {
            geometryIndexResults = [_rtreeIndex queryWithBoundingBox:[[GPKGBoundingBox alloc]
                                                                              initWithMinLongitudeDouble:geoBboxDeg.ll.x
                                                                              andMaxLongitudeDouble:geoBboxDeg.ur.x
                                                                              andMinLatitudeDouble:geoBboxDeg.ll.y
                                                                              andMaxLatitudeDouble:geoBboxDeg.ur.y]];
        } @catch (NSException *exception) {
            geometryIndexResults = nil;
            [NSThread sleepForTimeInterval:0.5];
        }
    }
    GPKGRTreeIndexResults *featureIndexResults = [[GPKGRTreeIndexResults alloc] initWithRTreeIndex:_rtreeIndex andResults:geometryIndexResults];
    
    int n = featureIndexResults.count;
    unsigned long totalBytes = 0;
    
    if (n > 0 && tileID.level == _targetLevel) {
        GPKGResultSet *results = [featureIndexResults getResults];
        
        NSArray *columnNames;
        
        while([results moveToNext]) {
            
            
            GPKGFeatureRow *row = [_rtreeIndex getFeatureRowWithResultSet:results];
            GPKGGeometryData *geometryData = [row getGeometry];
            
            if (!columnNames)
                columnNames = [row getColumnNames];

            totalBytes += geometryData.bytes.length;
            if (totalBytes > GPKG_FEATURE_TILE_SOURCE_MAX_BYTES && _targetLevel < _maxZoom)
                break;
            
            if(geometryData != nil && !geometryData.empty){
                
                WKBGeometry * geometry = geometryData.geometry;
                if(geometry != nil) {
                    
                    geometry = [_geomProjTransform transformGeometry:geometry];
                    
                    NSMutableArray *pointObjs = [NSMutableArray array];
                    NSMutableArray *linestringObjs = [NSMutableArray array];
                    NSMutableArray *polygonObjs = [NSMutableArray array];
            
                    NSMutableDictionary *attributes = [NSMutableDictionary new];
                    attributes[@"geometry_type"] = [WKBGeometryTypes name:geometry.geometryType];
                    
                    for (NSString *columnName in columnNames) {
                        
                        GPKGUserColumn *userColumn = [row getColumnWithColumnName:columnName];
                        enum GPKGDataType dt = userColumn.dataType;
                        switch (dt) {
                            case GPKG_DT_BOOLEAN:
                            case GPKG_DT_TINYINT:
                            case GPKG_DT_SMALLINT:
                            case GPKG_DT_MEDIUMINT:
                            case GPKG_DT_INT:
                            case GPKG_DT_INTEGER:
                            case GPKG_DT_FLOAT:
                            case GPKG_DT_DOUBLE:
                            case GPKG_DT_REAL:
                            case GPKG_DT_TEXT:
                            case GPKG_DT_DATE:
                            case GPKG_DT_DATETIME:
                                attributes[columnName] = [row getValueWithColumnName:columnName];
                            default:
                                continue;
                        }
                    }
                    
                    NSArray *styles = [self.styleDelegate stylesForFeatureWithAttributes:attributes
                                                                                  onTile:tileID
                                                                                 inLayer:@""
                                                                                   viewC:_viewC];
                    if (!styles || styles.count == 0)
                        continue;

                    
                    if (geometry.geometryType == WKB_LINESTRING) {
                        
                        WKBLineString *lineString = (WKBLineString *)geometry;
                        if (![self processLinestring:lineString withTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andLinestringObjs:linestringObjs])
                            n -= 1;
                        
                    } else if (geometry.geometryType == WKB_POLYGON) {
                        
                        WKBPolygon *polygon = (WKBPolygon *)geometry;
                        if (![self processPolygon:polygon withTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andLinestringObjs:linestringObjs andPolygonObjs:polygonObjs])
                            n -= 1;
                        
                    } else if (geometry.geometryType == WKB_POINT) {
                        WKBPoint *point = (WKBPoint *)geometry;
                        MaplyCoordinate coord = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
                        MaplyVectorObject *vecObj = [[MaplyVectorObject alloc] initWithPoint:coord attributes:nil];
                        [pointObjs addObject:vecObj];
                        
                    } else if (geometry.geometryType == WKB_MULTIPOINT) {
                        
                        WKBMultiPoint *multiPoint = (WKBMultiPoint *)geometry;
                        MaplyVectorObject *multiPointObj;
                        MaplyVectorObject *vecObj;
                        MaplyCoordinate coord;
                        
                        for (WKBPoint *point in [multiPoint getPoints]) {
                            coord = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
                            vecObj = [[MaplyVectorObject alloc] initWithPoint:coord attributes:nil];
                            if (!multiPointObj)
                                multiPointObj = vecObj;
                            else
                                [multiPointObj mergeVectorsFrom:vecObj];
                        }
                        [pointObjs addObject:multiPointObj];
                    } else if (geometry.geometryType == WKB_MULTILINESTRING) {
                        
                        WKBMultiLineString *multiLineString = (WKBMultiLineString *)geometry;
                        for (WKBLineString *lineString in [multiLineString getLineStrings]) {
                            [self processLinestring:lineString withTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andLinestringObjs:linestringObjs];
                        }
                    } else if (geometry.geometryType == WKB_MULTIPOLYGON) {
                        
                        WKBMultiPolygon *multiPolygon = (WKBMultiPolygon *)geometry;
                        for (WKBPolygon *polygon in [multiPolygon getPolygons]) {
                            [self processPolygon:polygon withTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andLinestringObjs:linestringObjs andPolygonObjs:polygonObjs];
                        }
                    } else {
                        NSLog(@"GPKGFeatureTileStyler; Skipping geometryType %i", geometry.geometryType);
                        n -= 1;
                    }
                    
                    NSMutableArray *allVecObjs = [NSMutableArray array];
                    [allVecObjs addObjectsFromArray:pointObjs];
                    [allVecObjs addObjectsFromArray:linestringObjs];
                    [allVecObjs addObjectsFromArray:polygonObjs];
                    
                    for (MaplyVectorObject *vecObj in allVecObjs) {
                        for(NSObject<MaplyVectorStyle> *style in styles) {
                            NSMutableArray *featuresForStyle = featureStyles[style.uuid];
                            if(!featuresForStyle) {
                                featuresForStyle = [NSMutableArray new];
                                featureStyles[style.uuid] = featuresForStyle;
                            }
                            [featuresForStyle addObject:vecObj];
                        }
                        [GPKGFeatureAttributeAccess setAttributes:attributes forVectorObject:vecObj];
                    }

                }
            }
            
        }
        [results close];
    }
    
    if (totalBytes > GPKG_FEATURE_TILE_SOURCE_MAX_BYTES && _targetLevel < _maxZoom) {
        _targetLevel += 1;
        NSLog(@"incrementing _targetLevel to %i", _targetLevel);
        return 0;
    }
    
    [featureIndexResults close];
    
    NSArray *symbolizerKeys = [featureStyles.allKeys sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]]];
    for(id key in symbolizerKeys) {
        NSObject<MaplyVectorStyle> *symbolizer = [self.styleDelegate styleForUUID:key viewC:_viewC];
        NSArray *features = featureStyles[key];
        [compObjs addObjectsFromArray:[symbolizer buildObjects:features forTile:tileID viewC:_viewC]];
    }
    
    return n;
    
}



- (bool) processLinestring:(WKBLineString *)lineString withTileID:(MaplyTileID)tileID andGeoBBox:(MaplyBoundingBox)geoBbox andGeoBBoxDeg:(MaplyBoundingBox)geoBboxDeg andLinestringObjs:(NSMutableArray *)linestringObjs {
    
    MaplyCoordinate staticCoords[GPKG_FEATURE_TILE_SOURCE_MAX_POINTS];
    bool processed = true;
    
    if ([lineString.numPoints intValue] > 0 && [lineString.numPoints intValue] < GPKG_FEATURE_TILE_SOURCE_MAX_POINTS) {
        
        for (int i=0; i<[lineString.numPoints intValue]; i++) {
            WKBPoint *point = lineString.points[i];
            staticCoords[i] = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
        }
        
        MaplyVectorObject *vecObj = [[MaplyVectorObject alloc] initWithLineString:staticCoords numCoords:[lineString.numPoints intValue] attributes:nil];
        
        MaplyVectorObject *clipped = [vecObj clipToMbr:geoBbox.ll upperRight:geoBbox.ur];
        
        [linestringObjs addObject:clipped];
        
    } else if ([lineString.numPoints intValue] > 0) {
        NSLog(@"GPKGFeatureTileStyler processLineString; skip %i %i %i %i", tileID.level, tileID.x, tileID.y, [lineString.numPoints intValue]);
        processed = false;
    }
    
    return processed;
}



- (bool) processPolygon:(WKBPolygon *)polygon withTileID:(MaplyTileID)tileID andGeoBBox:(MaplyBoundingBox)geoBbox andGeoBBoxDeg:(MaplyBoundingBox)geoBboxDeg andLinestringObjs:(NSMutableArray *)linestringObjs  andPolygonObjs:(NSMutableArray *)polygonObjs {
    
    MaplyCoordinate staticCoords[GPKG_FEATURE_TILE_SOURCE_MAX_POINTS];
    bool processed = true;
    
    MaplyVectorObject *polyVecObj;
    NSMutableArray *lineVecObjs = [NSMutableArray array];
    
    for (WKBLineString *ring in polygon.rings) {
        if ([ring.numPoints intValue] < GPKG_FEATURE_TILE_SOURCE_MAX_POINTS) {
            for (int i=0; i<[ring.numPoints intValue]; i++) {
                WKBPoint *point = ring.points[i];
                staticCoords[i] = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
            }
            if (ring == polygon.rings[0]) {
                polyVecObj = [[MaplyVectorObject alloc] initWithAreal:staticCoords numCoords:[ring.numPoints intValue]-1 attributes:nil];
            } else
                [polyVecObj addHole:staticCoords numCoords:[ring.numPoints intValue]-1];
            [lineVecObjs addObject:[[MaplyVectorObject alloc] initWithLineString:staticCoords numCoords:[ring.numPoints intValue] attributes:nil]];
        } else {
            NSLog(@"GPKGFeatureTileStyler processPolygon; skip %i %i %i %i", tileID.level, tileID.x, tileID.y, [ring.numPoints intValue]);
            polyVecObj = nil;
            break;
        }
    }
    if (polyVecObj) {
        
        MaplyVectorObject *clipped = [polyVecObj clipToMbr:geoBbox.ll upperRight:geoBbox.ur];
        
        if (clipped && clipped.vectorType == MaplyVectorArealType) {
            [polygonObjs addObject:clipped];
            for (MaplyVectorObject *lineVecObj in lineVecObjs) {
                clipped = [lineVecObj clipToMbr:geoBbox.ll upperRight:geoBbox.ur];
                [linestringObjs addObject:clipped];
            }
            
        } else {
            processed = false;
        }
        
        
    } else {
        processed = false;
    }
    
    return processed;
}




@end


@implementation GPKGFeatureTileSource {
    GPKGGeoPackage *_geoPackage;
    GPKGFeatureDao *_featureDao;
    GPKGRTreeIndex *_rtreeIndex;

    int _targetLevel, _minZoom, _maxZoom;
    
    NSDictionary *_gridDesc;
    UIImage *_markerImage;
    
    NSDictionary *_bounds;
    MaplyCoordinate _center;
    
    NSMutableDictionary *_loadedTiles;
    
    BOOL _isDegree;
    GPKGProjection *_proj4326;
    
    GPKGGeometryProjectionTransform *_geomProjTransform;
    
    NSURL *_sldURL;
    NSData *_sldData;
    SLDStyleSet *_styleSet;
    GPKGFeatureTileStyler *_tileParser;
}

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName bounds:(NSDictionary *)bounds sldURL:(NSURL *)sldURL sldData:(NSData *)sldData minZoom:(unsigned int)minZoom maxZoom:(unsigned int)maxZoom {
    self = [super init];
    if (self) {
        _geoPackage = geoPackage;
        @synchronized (_geoPackage) {
            _featureDao = [_geoPackage getFeatureDaoWithTableName:tableName];
            _bounds = bounds;
            _minZoom = minZoom;
            _maxZoom = maxZoom;
            
            if (!_featureDao) {
                NSLog(@"GPKGFeatureTileSource: Error accessing Feature DAO.");
                return nil;
            }

            
            _gridDesc = @{
                         kMaplyColor: [UIColor greenColor],
                         kMaplyEnable: @(NO),
                         kMaplyFilled: @(NO),
                         kMaplyVecWidth: @(5.0),
                         kMaplyDrawPriority: @(kMaplyImageLayerDrawPriorityDefault + 220)
                         };
            
            _markerImage = [UIImage imageNamed:@"map_pin"];
            
            

            
            GPKGSpatialReferenceSystemDao * srsDao = [_geoPackage getSpatialReferenceSystemDao];
            GPKGSpatialReferenceSystem * srs = (GPKGSpatialReferenceSystem *)[srsDao queryForIdObject:_featureDao.projection.epsg];
            if (!srs || !srs.organization || !srs.organizationCoordsysId) {
                NSLog(@"GPKGFeatureTileSource: Error accessing SRS.");
                return nil;
            }
            NSArray *bounds = _bounds[ [srs.organizationCoordsysId stringValue] ];
            MaplyBoundingBox bbox;
            bbox.ll.x = [(NSNumber *)bounds[0] floatValue];
            bbox.ll.y = [(NSNumber *)bounds[1] floatValue];
            bbox.ur.x = [(NSNumber *)bounds[2] floatValue];
            bbox.ur.y = [(NSNumber *)bounds[3] floatValue];
            _isDegree = [(NSNumber *)bounds[6] boolValue];
            _proj4326 = [GPKGProjectionFactory getProjectionWithInt:4326];
            
            GPKGProjectionTransform *projTransform = [[GPKGProjectionTransform alloc] initWithFromSrs:srs andToEpsg:4326];
            _geomProjTransform = [[GPKGGeometryProjectionTransform alloc] initWithProjectionTransform:projTransform];
            
            if (_isDegree) {
                bbox.ll.x = RAD_TO_DEG * bbox.ll.x;
                bbox.ll.y = RAD_TO_DEG * bbox.ll.y;
                bbox.ur.x = RAD_TO_DEG * bbox.ur.x;
                bbox.ur.y = RAD_TO_DEG * bbox.ur.y;
            } else {
                GPKGBoundingBox *srsBBox = [[GPKGBoundingBox alloc] initWithMinLongitudeDouble:bbox.ll.x andMaxLongitudeDouble:bbox.ur.x andMinLatitudeDouble:bbox.ll.y andMaxLatitudeDouble:bbox.ur.y];
                srsBBox = [projTransform transformWithBoundingBox:srsBBox];
                bbox.ll.x = srsBBox.minLongitude.doubleValue;
                bbox.ll.y = srsBBox.minLatitude.doubleValue;
                bbox.ur.x = srsBBox.maxLongitude.doubleValue;
                bbox.ur.y = srsBBox.maxLatitude.doubleValue;
            }

            _rtreeIndex = [[GPKGRTreeIndex alloc] initWithGeoPackage:_geoPackage andFeatureDao:_featureDao];
            // table is already indexed, so call this in same thread
            [_rtreeIndex indexTable];
            
            GPKGBoundingBox *gpkgBBox = [_rtreeIndex getMinimalBoundingBox];
            
            GPKGBoundingBox *gpkgBBoxTransformed = gpkgBBox;
            if (!_isDegree)
                gpkgBBoxTransformed = [projTransform transformWithBoundingBox:gpkgBBox];
            MaplyCoordinate p;
            p.x = (gpkgBBoxTransformed.minLongitude.doubleValue + gpkgBBoxTransformed.maxLongitude.doubleValue)/2.0;
            p.y = (gpkgBBoxTransformed.minLatitude.doubleValue + gpkgBBoxTransformed.maxLatitude.doubleValue)/2.0;
            _center = MaplyCoordinateMakeWithDegrees(p.x, p.y);
            
            _loadedTiles = [NSMutableDictionary dictionary];
            
            
            long totalFeatureSizeBytes = [_featureDao getTotalFeaturesSize];
            int numFeatures = [_featureDao count];
            if (totalFeatureSizeBytes == -1 || numFeatures < 1) {
                NSLog(@"GPKGFeatureTileSource: Error calculating display level.");
                return nil;
            }
            float avgFeatureSizeBytes = (float)totalFeatureSizeBytes / (float)numFeatures;
            
            /*  This is just a heuristic calculation to approximate the number of points per geometry in the table.
                The 43.0 offset is 40 + 3. 40 is the estimated GeoPackageBinaryHeader size. 3 is the approximate constant contribution to the WKB size.  And 18 is the approximate variable contribution to the WKB size.
             */
            float avgNumPoints = MAX((avgFeatureSizeBytes - 43.0) / 18.0, 1.0);
            
            NSLog(@"totalFeatureSizeBytes %i, numFeatures %i, avgFeatureSizeBytes %f", totalFeatureSizeBytes, numFeatures, avgFeatureSizeBytes);
            
            enum WKBGeometryType geomType = [_featureDao getGeometryType];
            int maxFeatures = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT / avgNumPoints;

            float featuresPerTile = (float)maxFeatures / (float)GPKG_FEATURE_TILE_SOURCE_TARGET_TILE_COUNT * 0.5;
            
            
            if ((gpkgBBox.minLongitude.doubleValue == gpkgBBox.maxLongitude.doubleValue) || (gpkgBBox.minLatitude.doubleValue == gpkgBBox.maxLatitude.doubleValue))
                _targetLevel = self.minZoom;
            else {
                _targetLevel = self.maxZoom;
                for (int level=self.minZoom; level<self.maxZoom; level++) {
                    double xSridUnitsPerTile = (bbox.ur.x - bbox.ll.x) / (1 << level);
                    double ySridUnitsPerTile = (bbox.ur.y - bbox.ll.y) / (1 << level);
                    
                    MaplyBoundingBox bboxSnapped;
                    bboxSnapped.ll.x = bbox.ll.x + round((gpkgBBox.minLongitude.doubleValue - bbox.ll.x) / xSridUnitsPerTile) * xSridUnitsPerTile;
                    bboxSnapped.ll.y = bbox.ll.y + round((gpkgBBox.minLatitude.doubleValue - bbox.ll.y) / ySridUnitsPerTile) * ySridUnitsPerTile;
                    
                    bboxSnapped.ur.x = bbox.ur.x - round((bbox.ur.x - gpkgBBox.maxLongitude.doubleValue) / xSridUnitsPerTile) * xSridUnitsPerTile;
                    bboxSnapped.ur.y = bbox.ur.y - round((bbox.ur.y - gpkgBBox.maxLatitude.doubleValue) / ySridUnitsPerTile) * ySridUnitsPerTile;
                    
                    int numTiles = (int)((bboxSnapped.ur.x - bboxSnapped.ll.x) / xSridUnitsPerTile) * (int)((bboxSnapped.ur.y - bboxSnapped.ll.y) / ySridUnitsPerTile);
                    
                    if ( ((float)numFeatures / (float)numTiles) < featuresPerTile ) {
                        _targetLevel = level;
                        break;
                    }
                }
            }
            NSLog(@"_targetLevel: %i", _targetLevel);
            _sldURL = sldURL;
            _sldData = sldData;
        }
    }
    return self;
}

- (void)close {
    @synchronized (_geoPackage) {
        _rtreeIndex = nil;
        _featureDao = nil;
        [_geoPackage close];
        _geoPackage = nil;
    }
}

- (int)minZoom {
    return _minZoom;
}

- (int)maxZoom {
    return _maxZoom;
}

- (MaplyCoordinate)center {
    return _center;
}





- (void)startFetchForTile:(MaplyTileID)tileID forLayer:(MaplyQuadPagingLayer *__nonnull)layer {
    
    MaplyBoundingBox geoBbox = [layer geoBoundsForTile:tileID];
    
    @synchronized (self) {
        if (!_tileParser) {
            _styleSet = [[SLDStyleSet alloc] initWithViewC:layer.viewC useLayerNames:NO relativeDrawPriority:0];
            if (_sldData)
                [_styleSet loadSldData:_sldData baseURL:[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject]];
            else
                [_styleSet loadSldURL:_sldURL];

            _tileParser = [[GPKGFeatureTileStyler alloc] initWithStyle:_styleSet viewC:layer.viewC targetLevel:_targetLevel maxZoom:self.maxZoom markerImage:_markerImage rtreeIndex:_rtreeIndex geomProjTransform:_geomProjTransform];
        }
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if ([self isParentLoaded:tileID]) {
            [layer tileFailedToLoad:tileID];
            return;
        }
        
        MaplyBoundingBox geoBboxDeg;
        geoBboxDeg.ll.x = geoBbox.ll.x*180.0/M_PI;
        geoBboxDeg.ll.y = geoBbox.ll.y*180.0/M_PI;
        geoBboxDeg.ur.x = geoBbox.ur.x*180.0/M_PI;
        geoBboxDeg.ur.y = geoBbox.ur.y*180.0/M_PI;
        
        int n;
        NSMutableArray *compObjs = [NSMutableArray array];
        bool complete = true;
        @synchronized (_geoPackage) {
            n = [_tileParser buildObjectsWithTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andCompObjs:compObjs];
        }
        
        if (compObjs.count == 0) {
        
            complete = false;
            
            if (n > 0 && tileID.level > 5) {
                
                MaplyCoordinate coords[5];
                coords[0] = MaplyCoordinateMake(geoBbox.ll.x, geoBbox.ll.y);
                coords[1] = MaplyCoordinateMake(geoBbox.ur.x, geoBbox.ll.y);
                coords[2] = MaplyCoordinateMake(geoBbox.ur.x, geoBbox.ur.y);
                coords[3] = MaplyCoordinateMake(geoBbox.ll.x, geoBbox.ur.y);
                coords[4] = MaplyCoordinateMake(geoBbox.ll.x, geoBbox.ll.y);
                MaplyVectorObject *vecObj = [[MaplyVectorObject alloc] initWithLineString:coords numCoords:5 attributes:nil];
                
                MaplyComponentObject *vecCompObj = [layer.viewC addVectors:@[vecObj] desc:_gridDesc mode:MaplyThreadCurrent];
                
                [compObjs addObject:vecCompObj];
            }
        }
        
        if (n > 0)
            [layer addData:compObjs forTile:tileID style:MaplyDataStyleReplace];
        
        if (complete)
            [self setLoaded:tileID];
        
        [layer tileDidLoad:tileID];
    });
}

- (void)tileDidUnload:(MaplyTileID)tileID {
    [self clearLoaded:tileID];
}

- (void)setLoaded:(MaplyTileID)tileID {
    @synchronized (self) {
        if (!_loadedTiles[@(tileID.level)])
            _loadedTiles[@(tileID.level)] = [NSMutableDictionary dictionary];
        NSMutableDictionary *levelDict = _loadedTiles[@(tileID.level)];

        if (!levelDict[@(tileID.x)])
            levelDict[@(tileID.x)] = [NSMutableDictionary dictionary];
        NSMutableDictionary *columnDict = levelDict[@(tileID.x)];
        
        columnDict[@(tileID.y)] = @(true);
    }
}

- (void)clearLoaded:(MaplyTileID)tileID {
    @synchronized (self) {
        if (!_loadedTiles[@(tileID.level)])
            return;
        NSMutableDictionary *levelDict = _loadedTiles[@(tileID.level)];
        if (!levelDict[@(tileID.x)])
            return;
        NSMutableDictionary *columnDict = levelDict[@(tileID.x)];
        
        if (columnDict[@(tileID.y)])
            [columnDict removeObjectForKey:@(tileID.y)];
        if (columnDict.count == 0)
            [levelDict removeObjectForKey:@(tileID.x)];
        if (levelDict.count == 0)
            [_loadedTiles removeObjectForKey:@(tileID.level)];
    }
}

- (bool)isParentLoaded:(MaplyTileID)tileID {
    @synchronized (self) {
        MaplyTileID parentTileID;
        parentTileID.level = tileID.level-1;
        parentTileID.x = tileID.x/2;
        parentTileID.y = tileID.y/2;
        
        if (!_loadedTiles[@(parentTileID.level)])
            return false;
        NSMutableDictionary *levelDict = _loadedTiles[@(parentTileID.level)];
        
        if (!levelDict[@(parentTileID.x)])
            return false;
        NSMutableDictionary *columnDict = levelDict[@(parentTileID.x)];
        
        if (columnDict[@(parentTileID.y)])
            return true;
        return false;
    }
}


-(void) setMax: (int) max {
    
}

-(void) addProgress: (int) progress {
}

-(BOOL) isActive {
    return YES;
}

-(BOOL) cleanupOnCancel {
    return YES;
}

-(void) completed {
    NSLog(@"index completed");
}

-(void) failureWithError: (NSString *) error {
    
}

@end
