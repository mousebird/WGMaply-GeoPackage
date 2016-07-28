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

@implementation GPKGFeatureTileSource {
    GPKGGeoPackage *_geoPackage;
    GPKGFeatureDao *_featureDao;
    GPKGFeatureIndexManager *_indexer;
    
    int _maxFeaturesPerTile;
    
    NSDictionary *_labelDesc, *_linestringDesc, *_polygonDesc, *_markerDesc, *_gridDesc;
    UIImage *_markerImage;
    
    NSDictionary *_bounds;
}

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName bounds:(NSDictionary *)bounds {
    self = [super init];
    if (self) {
        _geoPackage = geoPackage;
        _featureDao = [_geoPackage getFeatureDaoWithTableName:tableName];
        _bounds = bounds;
        
        
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
            _maxFeaturesPerTile = 100;
        else if (geomType == WKB_LINESTRING)
            _maxFeaturesPerTile = 20;
        else if (geomType == WKB_POLYGON)
            _maxFeaturesPerTile = 100;

    
        
        _indexer = [[GPKGFeatureIndexManager alloc] initWithGeoPackage:_geoPackage andFeatureDao:_featureDao];
        [_indexer setProgress:self];
        NSLog(@"starting index");
        int n = [_indexer indexWithFeatureIndexType:GPKG_FIT_GEOPACKAGE];
        NSLog(@"finished index %i", n);
        NSLog(@"in bbox: %i", [_indexer countWithBoundingBox:[[GPKGBoundingBox alloc] initWithMinLongitudeDouble:-117.26 andMaxLongitudeDouble:-117.14 andMinLatitudeDouble:-90.0 andMaxLatitudeDouble:90.0]]);
        
        
        
        
        
        if (!_featureDao) {
            NSLog(@"GPKGFeatureTileSource: Error accessing Feature DAO.");
            return nil;
        }
        
    }
    return self;
}

- (int)minZoom {
    return 1;
}

- (int)maxZoom {
    return 20;
}

- (void)startFetchForTile:(MaplyTileID)tileID forLayer:(MaplyQuadPagingLayer *__nonnull)layer {
    
    static MaplyCoordinate staticCoords[4096];
    
    MaplyBoundingBox geoBbox = [layer geoBoundsForTile:tileID];
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
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
                                                andMaxLatitudeDouble:urLatDeg]];
        
        
        if (n > 0 && n < _maxFeaturesPerTile) {
            GPKGFeatureIndexResults *indexResults = [_indexer queryWithBoundingBox:[[GPKGBoundingBox alloc]
                                            initWithMinLongitudeDouble:llLonDeg
                                            andMaxLongitudeDouble:urLonDeg
                                            andMinLatitudeDouble:llLatDeg
                                            andMaxLatitudeDouble:urLatDeg]];
            
            GPKGResultSet *results = [indexResults getResults];
            while([results moveToNext]) {
                
                GPKGFeatureTableIndex *tableIndex = [_indexer getFeatureTableIndex];
                GPKGFeatureRow *row = [tableIndex getFeatureRowWithResultSet:results];
                
                GPKGGeometryData *geometryData = [row getGeometry];
                
                if(geometryData != nil && !geometryData.empty){
                    
                    WKBGeometry * geometry = geometryData.geometry;
                    
                    
                    if(geometry != nil) {
                        
                        if (geometry.geometryType == WKB_LINESTRING) {
                            
                            WKBLineString *lineString = (WKBLineString *)geometry;
                            
                            if ([lineString.numPoints intValue] > 0 && [lineString.numPoints intValue] < 4096) {
                                
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
                            MaplyVectorObject *vecObj;
                            for (WKBLineString *ring in polygon.rings) {
                                if ([ring.numPoints intValue] < 4096) {
                                    //NSLog(@"------------");
                                    for (int i=0; i<[ring.numPoints intValue]; i++) {
                                        WKBPoint *point = ring.points[i];
                                        staticCoords[i] = MaplyCoordinateMakeWithDegrees([point.x doubleValue], [point.y doubleValue]);
//                                        if (i==0 || i==[ring.numPoints intValue]-1)
//                                            NSLog(@"(%f, %f)", [point.x doubleValue], [point.y doubleValue]);
                                    }
                                    if (ring == polygon.rings[0]) {
                                        vecObj = [[MaplyVectorObject alloc] initWithAreal:staticCoords numCoords:[ring.numPoints intValue] attributes:nil];
                                        MaplyCoordinate centroid = [vecObj centroid];
                                        
                                        MaplyCoordinate cen, ll, ur;
                                        bool success = [vecObj largestLoopCenter:&cen mbrLL:&ll mbrUR:&ur];
                                        
                                        if (!success ||
                                            geoBbox.ll.x > cen.x ||
                                            geoBbox.ur.x <= cen.x ||
                                            geoBbox.ll.y > cen.y ||
                                            geoBbox.ur.y <= cen.y) {

                                            NSLog(@"tossing poly %f %f %f %f ; %f %f", geoBbox.ll.x, geoBbox.ur.x, geoBbox.ll.y, geoBbox.ur.y, centroid.x, centroid.y);
                                            vecObj = nil;
                                            n -= 1;
                                            break;
                                        }
//                                        else
//                                            NSLog(@"keeping poly %f %f %f %f ; %f %f", geoBbox.ll.x, geoBbox.ur.x, geoBbox.ll.y, geoBbox.ur.y, centroid.x, centroid.y);


                                        
//                                        if (centroid.x == kMaplyNullCoordinate.x ||
//                                            centroid.y == kMaplyNullCoordinate.y ||
//                                            geoBbox.ll.x > centroid.x ||
//                                            geoBbox.ur.x <= centroid.x ||
//                                            geoBbox.ll.y > centroid.y ||
//                                            geoBbox.ur.y <= centroid.y) {
//                                            
//                                            NSLog(@"tossing poly %f %f %f %f ; %f %f", geoBbox.ll.x, geoBbox.ur.x, geoBbox.ll.y, geoBbox.ur.y, centroid.x, centroid.y);
//                                            vecObj = nil;
//                                            break;
//                                        } else
//                                            NSLog(@"keeping poly %f %f %f %f ; %f %f", geoBbox.ll.x, geoBbox.ur.x, geoBbox.ll.y, geoBbox.ur.y, centroid.x, centroid.y);
                                        
                                        
                                        
                                        
                                    } else
                                        [vecObj addHole:staticCoords numCoords:[ring.numPoints intValue]];
                                    
                                    
                                } else {
                                    NSLog(@"skip %i %i %i %i", tileID.level, tileID.x, tileID.y, [ring.numPoints intValue]);
                                    vecObj = nil;
                                    n -= 1;
                                    break;
                                }
                                
                            }
                            if (vecObj) {
                                [polygonObjs addObject:vecObj];
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
        
        
        
        
        
//        NSLog(@"tile %i %i %i %i", tileID.level, tileID.x, tileID.y, n);
        
        
        
        NSMutableArray *compObjs = [NSMutableArray array];

        if (linestringObjs.count > 0) {
            MaplyComponentObject *lsCompObj = [layer.viewC addVectors:linestringObjs desc:_linestringDesc mode:MaplyThreadCurrent];
            [compObjs addObject:lsCompObj];
        } else if (polygonObjs.count > 0) {
            MaplyComponentObject *fillCompObj = [layer.viewC addVectors:polygonObjs desc:_polygonDesc mode:MaplyThreadCurrent];
            [compObjs addObject:fillCompObj];
            MaplyComponentObject *outlineCompObj = [layer.viewC addVectors:polygonObjs desc:_linestringDesc mode:MaplyThreadCurrent];
            [compObjs addObject:outlineCompObj];
        } else if (markerObjs.count > 0) {
            MaplyComponentObject *markerCompObj = [layer.viewC addScreenMarkers:markerObjs desc:_markerDesc mode:MaplyThreadCurrent];
            [compObjs addObject:markerCompObj];
        } else if (n > 0) {
        
            MaplyScreenLabel *label = [[MaplyScreenLabel alloc] init];
            label.loc = MaplyCoordinateMakeWithDegrees(
                                                       (llLonDeg + urLonDeg) / 2.0,
                                                       (llLatDeg + urLatDeg) / 2.0);
            label.text = [@(n) stringValue];
            //label.text = [NSString stringWithFormat:@"%i %i %i", tileID.x, tileID.y, n];
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
        
//        dispatch_async(dispatch_get_main_queue(), ^{
        if (n > 0) {
            [layer addData:compObjs forTile:tileID style:MaplyDataStyleReplace];
        }
        [layer tileDidLoad:tileID];
        
            
            
//        });
    });
    
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
