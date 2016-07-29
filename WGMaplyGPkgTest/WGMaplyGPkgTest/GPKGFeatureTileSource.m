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
    
    int _maxFeaturesPerTile;
    
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
        
        
        enum WKBGeometryType geomType = [_featureDao getGeometryType];
        if (geomType == WKB_POINT)
            _maxFeaturesPerTile = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POINT;
        else if (geomType == WKB_LINESTRING)
            _maxFeaturesPerTile = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_LINESTRING;
        else if (geomType == WKB_POLYGON)
            _maxFeaturesPerTile = GPKG_FEATURE_TILE_SOURCE_MAX_FEATURES_POLYGON;

        
        GPKGSpatialReferenceSystemDao * srsDao = [_geoPackage getSpatialReferenceSystemDao];
        GPKGSpatialReferenceSystem * srs = (GPKGSpatialReferenceSystem *)[srsDao queryForIdObject:_featureDao.projection.epsg];
        if (!srs || !srs.organization || !srs.organizationCoordsysId) {
            NSLog(@"GPKGFeatureTileSource: Error accessing SRS.");
            return nil;
        }
        NSArray *bounds = _bounds[ [srs.organizationCoordsysId stringValue] ];
        _isDegree = [(NSNumber *)bounds[6] boolValue];
        _proj4326 = [GPKGProjectionFactory getProjectionWithInt:4326];
        
        GPKGProjectionTransform *projTransform = [[GPKGProjectionTransform alloc] initWithFromSrs:srs andToEpsg:4326];
        _geomProjTransform = [[GPKGGeometryProjectionTransform alloc] initWithProjectionTransform:projTransform];

        
        _indexer = [[GPKGFeatureIndexManager alloc] initWithGeoPackage:_geoPackage andFeatureDao:_featureDao];
        [_indexer setProgress:self];
        NSLog(@"starting index");
        int n = 0;
        @try {
            n = [_indexer indexWithFeatureIndexType:GPKG_FIT_GEOPACKAGE];
        } @catch (NSException *exception) {
            NSLog(@"Error in GPKGFeatureTileSource init");
            NSLog(@"%@", exception);
            return nil;
            
        }
        NSLog(@"finished index %i", n);
        
        GPKGBoundingBox *gpkgBBox = [_featureDao getBoundingBox];
        if (!_isDegree)
            gpkgBBox = [projTransform transformWithBoundingBox:gpkgBBox];
        MaplyCoordinate p;
        p.x = (gpkgBBox.minLongitude.doubleValue + gpkgBBox.maxLongitude.doubleValue)/2.0;
        p.y = (gpkgBBox.minLatitude.doubleValue + gpkgBBox.maxLatitude.doubleValue)/2.0;
        _center = MaplyCoordinateMakeWithDegrees(p.x, p.y);
        
        
        _loadedTiles = [NSMutableDictionary dictionary];
        
    }
    return self;
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


- (void)startFetchForTile:(MaplyTileID)tileID forLayer:(MaplyQuadPagingLayer *__nonnull)layer {
    
    static MaplyCoordinate staticCoords[GPKG_FEATURE_TILE_SOURCE_MAX_POINTS];
    
    MaplyBoundingBox geoBbox = [layer geoBoundsForTile:tileID];
    
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        if ([self isParentLoaded:tileID]) {
            [layer tileFailedToLoad:tileID];
            return;
        }
        
        
        double llLonDeg = geoBbox.ll.x*180.0/M_PI;
        double llLatDeg = geoBbox.ll.y*180.0/M_PI;
        double urLonDeg = geoBbox.ur.x*180.0/M_PI;
        double urLatDeg = geoBbox.ur.y*180.0/M_PI;
        
        
        NSMutableArray *linestringObjs = [NSMutableArray array];
        NSMutableArray *polygonObjs = [NSMutableArray array];
        NSMutableArray *markerObjs = [NSMutableArray array];
        
        int n = [_indexer countWithBoundingBox:[[GPKGBoundingBox alloc]
                                                initWithMinLongitudeDouble:llLonDeg
                                                andMaxLongitudeDouble:urLonDeg
                                                andMinLatitudeDouble:llLatDeg
                                                andMaxLatitudeDouble:urLatDeg] andProjection:_proj4326];
        
        
        if (n > 0 && n < _maxFeaturesPerTile) {
            GPKGFeatureTableIndex *tableIndex = [_indexer getFeatureTableIndex];
            GPKGFeatureIndexResults *indexResults = [_indexer queryWithBoundingBox:[[GPKGBoundingBox alloc]
                                            initWithMinLongitudeDouble:llLonDeg
                                            andMaxLongitudeDouble:urLonDeg
                                            andMinLatitudeDouble:llLatDeg
                                            andMaxLatitudeDouble:urLatDeg] andProjection:_proj4326];
            
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
                            
                            if ([lineString.numPoints intValue] > 0 && [lineString.numPoints intValue] < GPKG_FEATURE_TILE_SOURCE_MAX_POINTS) {
                                
                                for (int i=0; i<[lineString.numPoints intValue]; i++) {
                                    WKBPoint *point = lineString.points[i];
                                    staticCoords[i] = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
                                }
                                MaplyVectorObject *vecObj = [[MaplyVectorObject alloc] initWithLineString:staticCoords numCoords:[lineString.numPoints intValue] attributes:nil];
                                [linestringObjs addObject:vecObj];
                            } else if ([lineString.numPoints intValue] > 0) {
                                NSLog(@"skip %i %i %i %i", tileID.level, tileID.x, tileID.y, [lineString.numPoints intValue]);
                                n -= 1;
                            }
                        } else if (geometry.geometryType == WKB_POLYGON) {
                            
                            WKBPolygon *polygon = (WKBPolygon *)geometry;
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
                                
                                MaplyVectorObject *clipped = [polyVecObj clipToMbr:MaplyCoordinateMakeWithDegrees(llLonDeg, llLatDeg) upperRight:MaplyCoordinateMakeWithDegrees(urLonDeg, urLatDeg)];
                                
                                if (clipped && clipped.vectorType == MaplyVectorArealType) {
                                    [polygonObjs addObject:clipped];
                                    for (MaplyVectorObject *lineVecObj in lineVecObjs) {
                                        clipped = [lineVecObj clipToMbr:MaplyCoordinateMakeWithDegrees(llLonDeg, llLatDeg) upperRight:MaplyCoordinateMakeWithDegrees(urLonDeg, urLatDeg)];
                                        [linestringObjs addObject:clipped];
                                    }
                                    
                                } else {
                                    n -= 1;
                                }
                                
                                
                            } else {
                                n -= 1;
                            }
                            
                        } else if (geometry.geometryType == WKB_POINT) {
                            WKBPoint *point = (WKBPoint *)geometry;
                            
                            MaplyScreenMarker *marker = [[MaplyScreenMarker alloc] init];
                            marker.loc = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
                            marker.image = _markerImage;
                            marker.size = CGSizeMake( _markerImage.size.width/2.0, _markerImage.size.height/2.0);
                            
                            
                            [markerObjs addObject:marker];
                        } else {
                            NSLog(@"geometryType %i", geometry.geometryType);
                            n -= 1;
                        }
                    }
                }
                
            }
            [results close];
            [indexResults close];
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
            
                MaplyScreenLabel *label = [[MaplyScreenLabel alloc] init];
                label.loc = MaplyCoordinateMakeWithDegrees(
                                                           (llLonDeg + urLonDeg) / 2.0,
                                                           (llLatDeg + urLatDeg) / 2.0);
                label.text = [@(n) stringValue];
                label.layoutPlacement = kMaplyLayoutRight;
                
                MaplyComponentObject *labelCompObj = [layer.viewC addScreenLabels:@[label] desc:_labelDesc mode:MaplyThreadCurrent];
                
                MaplyCoordinate coords[5];
                coords[0] = MaplyCoordinateMakeWithDegrees(llLonDeg, llLatDeg);
                coords[1] = MaplyCoordinateMakeWithDegrees(urLonDeg, llLatDeg);
                coords[2] = MaplyCoordinateMakeWithDegrees(urLonDeg, urLatDeg);
                coords[3] = MaplyCoordinateMakeWithDegrees(llLonDeg, urLatDeg);
                coords[4] = MaplyCoordinateMakeWithDegrees(llLonDeg, llLatDeg);
                MaplyVectorObject *vecObj = [[MaplyVectorObject alloc] initWithLineString:coords numCoords:5 attributes:nil];
                
                MaplyComponentObject *vecCompObj = [layer.viewC addVectors:@[vecObj] desc:_gridDesc mode:MaplyThreadCurrent];
                
                compObjs = [NSMutableArray arrayWithArray:@[labelCompObj, vecCompObj]];
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
