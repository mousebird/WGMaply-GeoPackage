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

@implementation GPKGFeatureTileSource {
    GPKGGeoPackage *_geoPackage;
    GPKGFeatureDao *_featureDao;
    GPKGFeatureIndexManager *_indexer;

    int _targetLevel;
    
    NSDictionary *_labelDesc, *_linestringDesc, *_polygonDesc, *_markerDesc, *_gridDesc;
    UIImage *_markerImage;
    
    NSDictionary *_bounds;
    MaplyCoordinate _center;
    
    NSMutableDictionary *_loadedTiles;
    
    BOOL _isDegree;
    GPKGProjection *_proj4326;
    
    GPKGGeometryProjectionTransform *_geomProjTransform;
}

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName bounds:(NSDictionary *)bounds {
    self = [super init];
    if (self) {
        _geoPackage = geoPackage;
        @synchronized (_geoPackage) {
            _featureDao = [_geoPackage getFeatureDaoWithTableName:tableName];
            _bounds = bounds;
            
            if (!_featureDao) {
                NSLog(@"GPKGFeatureTileSource: Error accessing Feature DAO.");
                return nil;
            }

            
            _labelDesc = @{
                            kMaplyJustify           : @"left",
                            kMaplyDrawPriority      : @(kMaplyImageLayerDrawPriorityDefault + 230),
                            kMaplyFont              :
                                [UIFont systemFontOfSize:24.0],
                            kMaplyTextColor         : [UIColor greenColor],
                            kMaplyTextOutlineColor  : [UIColor blackColor],
                            kMaplyTextOutlineSize   : @(1.0),
                            kMaplyEnable            : @(NO)};
            _linestringDesc = @{
                         kMaplyColor: [UIColor yellowColor],
                         kMaplyEnable: @(NO),
                         kMaplyFilled: @(NO),
                         kMaplyVecWidth: @(5.0),
                         kMaplyDrawPriority: @(kMaplyImageLayerDrawPriorityDefault + 210)
                         };
            _polygonDesc = @{
                                kMaplyColor: [UIColor purpleColor],
                                kMaplyEnable: @(NO),
                                kMaplyFilled: @(YES),
                                kMaplyVecWidth: @(5.0),
                                kMaplyDrawPriority: @(kMaplyImageLayerDrawPriorityDefault + 200)
                                };
            _gridDesc = @{
                         kMaplyColor: [UIColor greenColor],
                         kMaplyEnable: @(NO),
                         kMaplyFilled: @(NO),
                         kMaplyVecWidth: @(5.0),
                         kMaplyDrawPriority: @(kMaplyImageLayerDrawPriorityDefault + 220)
                         };
            
            _markerDesc = @{kMaplyMinVis: @(0.0), kMaplyMaxVis: @(1.0), kMaplyFade: @(0.0), kMaplyDrawPriority: @(kMaplyImageLayerDrawPriorityDefault + 200), kMaplyEnable: @(NO)};
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
            }

            
            _indexer = [[GPKGFeatureIndexManager alloc] initWithGeoPackage:_geoPackage andFeatureDao:_featureDao];
            [_indexer setProgress:self];
            NSLog(@"GPKGFeatureTileSource: Starting index.");
            int n = 0;
            @try {
                n = [_indexer indexWithFeatureIndexType:GPKG_FIT_GEOPACKAGE];
            } @catch (NSException *exception) {
                NSLog(@"GPKGFeatureTileSource: Error indexing geometry.");
                NSLog(@"%@", exception);
                return nil;
                
            }
            NSLog(@"GPKGFeatureTileSource: Finished index.");
            
            GPKGBoundingBox *gpkgBBox = [_indexer getMinimalBoundingBox];
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
            float avgNumPoints = (avgFeatureSizeBytes - 43.0) / 18.0;
            
            NSLog(@"totalFeatureSizeBytes %ld numFeatures %i avgFeatureSizeBytes %f avgNumPoints %f _isDegree %i", totalFeatureSizeBytes, numFeatures, avgFeatureSizeBytes, avgNumPoints, _isDegree);
            
            enum WKBGeometryType geomType = [_featureDao getGeometryType];
            int maxFeatures;
            if (geomType == WKB_POINT || geomType == WKB_MULTIPOINT)
                maxFeatures = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT;
            else if (geomType == WKB_LINESTRING || geomType == WKB_MULTILINESTRING)
                maxFeatures = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_LINESTRING;
            else if (geomType == WKB_POLYGON || geomType == WKB_MULTIPOLYGON)
                maxFeatures = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POLYGON;
            else if (geomType == WKB_GEOMETRY || geomType == WKB_GEOMETRYCOLLECTION) {
                if (avgNumPoints > 2.5)
                    maxFeatures = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POLYGON;
                else
                    maxFeatures = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT;
            } else {
                NSLog(@"GPKGFeatureTileSource: unsupported geometry type.");
                return nil;
            }

            float featuresPerTile = (float)maxFeatures / (float)GPKG_FEATURE_TILE_SOURCE_TARGET_TILE_COUNT * 0.5;
            
            NSLog(@"maxFeatures %i featuresPerTile %f", maxFeatures, featuresPerTile);
            
            NSLog(@"gpkgBBox %f %f %f %f", gpkgBBox.minLongitude.doubleValue, gpkgBBox.maxLongitude.doubleValue, gpkgBBox.minLatitude.doubleValue, gpkgBBox.maxLatitude.doubleValue);
            NSLog(@"bbox %f %f %f %f", bbox.ll.x, bbox.ur.x, bbox.ll.y, bbox.ur.y);

            
            MaplySphericalMercator *mercProj = [[MaplySphericalMercator alloc] initWebStandard];
            _targetLevel = self.maxZoom;
            for (int level=self.minZoom; level<self.maxZoom; level++) {
                double xSridUnitsPerTile = (bbox.ur.x - bbox.ll.x) / (1 << level);
                double ySridUnitsPerTile = (bbox.ur.y - bbox.ll.y) / (1 << level);
                
                MaplyBoundingBox bboxSnapped;
                bboxSnapped.ll.x = bbox.ll.x + round((gpkgBBox.minLongitude.doubleValue - bbox.ll.x) / xSridUnitsPerTile) * xSridUnitsPerTile;
                bboxSnapped.ll.y = bbox.ll.y + round((gpkgBBox.minLatitude.doubleValue - bbox.ll.y) / ySridUnitsPerTile) * ySridUnitsPerTile;
                
                bboxSnapped.ur.x = bbox.ur.x - round((bbox.ur.x - gpkgBBox.maxLongitude.doubleValue) / xSridUnitsPerTile) * xSridUnitsPerTile;
                bboxSnapped.ur.y = bbox.ur.y - round((bbox.ur.y - gpkgBBox.maxLatitude.doubleValue) / ySridUnitsPerTile) * ySridUnitsPerTile;
                
                NSLog(@"bboxSnapped %f %f %f %f", bboxSnapped.ll.x, bboxSnapped.ur.x, bboxSnapped.ll.y, bboxSnapped.ur.y);
                
                int numTiles = (int)((bboxSnapped.ur.x - bboxSnapped.ll.x) / xSridUnitsPerTile) * (int)((bboxSnapped.ur.y - bboxSnapped.ll.y) / ySridUnitsPerTile);
                
                NSLog(@"numTiles %i", numTiles);
                
                if ( ((float)numFeatures / (float)numTiles) < featuresPerTile ) {
                    _targetLevel = level;
                    break;
                }
            }
            NSLog(@"_targetLevel %i", _targetLevel);
            
        }
    }
    return self;
}

- (void)close {
    @synchronized (_geoPackage) {
        _indexer = nil;
        _featureDao = nil;
        [_geoPackage close];
        _geoPackage = nil;
    }
}

- (int)minZoom {
    return 1;
}

- (int)maxZoom {
    return 20;
}

- (MaplyCoordinate)center {
    return _center;
}



- (bool) processLinestring:(WKBLineString *)lineString withTileID:(MaplyTileID)tileID andGeoBBox:(MaplyBoundingBox)geoBbox andGeoBBoxDeg:(MaplyBoundingBox)geoBboxDeg andLinestringObjs:(NSMutableArray *)linestringObjs {
    
    static MaplyCoordinate staticCoords[GPKG_FEATURE_TILE_SOURCE_MAX_POINTS];
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
        NSLog(@"skip %i %i %i %i", tileID.level, tileID.x, tileID.y, [lineString.numPoints intValue]);
        processed = false;
    }
    
    return processed;
}



- (bool) processPolygon:(WKBPolygon *)polygon withTileID:(MaplyTileID)tileID andGeoBBox:(MaplyBoundingBox)geoBbox andGeoBBoxDeg:(MaplyBoundingBox)geoBboxDeg andLinestringObjs:(NSMutableArray *)linestringObjs  andPolygonObjs:(NSMutableArray *)polygonObjs {
    
    static MaplyCoordinate staticCoords[GPKG_FEATURE_TILE_SOURCE_MAX_POINTS];
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
                polyVecObj = [[MaplyVectorObject alloc] initWithAreal:staticCoords numCoords:[ring.numPoints intValue] attributes:nil];
            } else
                [polyVecObj addHole:staticCoords numCoords:[ring.numPoints intValue]];
            [lineVecObjs addObject:[[MaplyVectorObject alloc] initWithLineString:staticCoords numCoords:[ring.numPoints intValue] attributes:nil]];
        } else {
            NSLog(@"skip %i %i %i %i", tileID.level, tileID.x, tileID.y, [ring.numPoints intValue]);
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


- (int) processGeometriesWithTileID:(MaplyTileID)tileID andGeoBBox:(MaplyBoundingBox)geoBbox andGeoBBoxDeg:(MaplyBoundingBox)geoBboxDeg andLinestringObjs:(NSMutableArray *)linestringObjs  andPolygonObjs:(NSMutableArray *)polygonObjs andMarkerObjs:(NSMutableArray *)markerObjs {
    
    static MaplyCoordinate staticCoords[GPKG_FEATURE_TILE_SOURCE_MAX_POINTS];
    
    if (tileID.level > _targetLevel)
        return 0;
    
    GPKGFeatureTableIndex *tableIndex = [_indexer getFeatureTableIndex];
    GPKGFeatureIndexResults *indexResults = [_indexer queryWithBoundingBox:[[GPKGBoundingBox alloc]
                                                                            initWithMinLongitudeDouble:geoBboxDeg.ll.x
                                                                            andMaxLongitudeDouble:geoBboxDeg.ur.x
                                                                            andMinLatitudeDouble:geoBboxDeg.ll.y
                                                                            andMaxLatitudeDouble:geoBboxDeg.ur.y] andProjection:_proj4326];
    
    int n = indexResults.count;
    
    if (n > 0 && tileID.level == _targetLevel) {
        
        GPKGResultSet *results = [indexResults getResults];
        while([results moveToNext]) {
            
            GPKGFeatureRow *row = [tableIndex getFeatureRowWithResultSet:results];
            GPKGGeometryData *geometryData = [row getGeometry];
            
            if(geometryData != nil && !geometryData.empty){
                
                WKBGeometry * geometry = geometryData.geometry;
                if(geometry != nil) {
                    
                    geometry = [_geomProjTransform transformGeometry:geometry];
                    
                    
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
                        
                        MaplyScreenMarker *marker = [[MaplyScreenMarker alloc] init];
                        marker.loc = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
                        marker.image = _markerImage;
                        marker.size = CGSizeMake( _markerImage.size.width/2.0, _markerImage.size.height/2.0);
                        [markerObjs addObject:marker];
                        
                    } else if (geometry.geometryType == WKB_MULTIPOINT) {
                        
                        WKBMultiPoint *multiPoint = (WKBMultiPoint *)geometry;
                        for (WKBPoint *point in [multiPoint getPoints]) {
                            MaplyScreenMarker *marker = [[MaplyScreenMarker alloc] init];
                            marker.loc = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
                            marker.image = _markerImage;
                            marker.size = CGSizeMake( _markerImage.size.width/2.0, _markerImage.size.height/2.0);
                            [markerObjs addObject:marker];
                        }
                    } else if (geometry.geometryType == WKB_MULTILINESTRING) {
                        WKBMultiLineString *multiLineString = (WKBMultiLineString *)geometry;
                        for (WKBLineString *lineString in [multiLineString getLineStrings]) {
                            // TODO: limit # of features ?
                            [self processLinestring:lineString withTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andLinestringObjs:linestringObjs];
                        }
                    } else if (geometry.geometryType == WKB_MULTIPOLYGON) {
                        WKBMultiPolygon *multiPolygon = (WKBMultiPolygon *)geometry;
                        for (WKBPolygon *polygon in [multiPolygon getPolygons]) {
                            // TODO: limit # of features ?
                            [self processPolygon:polygon withTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andLinestringObjs:linestringObjs andPolygonObjs:polygonObjs];
                        }
                    } else {
                        NSLog(@"geometryType %i", geometry.geometryType);
                        n -= 1;
                    }
                }
            }
            
        }
        [results close];
    }
    
    [indexResults close];
    return n;
    
}





- (void)startFetchForTile:(MaplyTileID)tileID forLayer:(MaplyQuadPagingLayer *__nonnull)layer {
    
    MaplyBoundingBox geoBbox = [layer geoBoundsForTile:tileID];
    
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
        
        
        NSMutableArray *linestringObjs = [NSMutableArray array];
        NSMutableArray *polygonObjs = [NSMutableArray array];
        NSMutableArray *markerObjs = [NSMutableArray array];
        
        int n;
        @synchronized (_geoPackage) {
            n = [self processGeometriesWithTileID:tileID andGeoBBox:geoBbox andGeoBBoxDeg:geoBboxDeg andLinestringObjs:linestringObjs andPolygonObjs:polygonObjs andMarkerObjs:markerObjs];
        }
        
        NSMutableArray *compObjs = [NSMutableArray array];
        bool complete = true;

        if (linestringObjs.count > 0 || polygonObjs.count > 0 || markerObjs.count > 0) {
            if (linestringObjs.count > 0) {
                MaplyComponentObject *lsCompObj = [layer.viewC addVectors:linestringObjs desc:_linestringDesc mode:MaplyThreadCurrent];
                [compObjs addObject:lsCompObj];
            }
            if (polygonObjs.count > 0) {
                MaplyComponentObject *fillCompObj = [layer.viewC addVectors:polygonObjs desc:_polygonDesc mode:MaplyThreadCurrent];
                [compObjs addObject:fillCompObj];
            }
            if (markerObjs.count > 0) {
                MaplyComponentObject *markerCompObj = [layer.viewC addScreenMarkers:markerObjs desc:_markerDesc mode:MaplyThreadCurrent];
                [compObjs addObject:markerCompObj];
            }
        } else {
            
            complete = false;
            
            if (n > 0) {
                
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
        
        if (complete) {
            [self setLoaded:tileID];
        }
        
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
