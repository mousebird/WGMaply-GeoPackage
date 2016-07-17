//
//  GPKGTileSource.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-07.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "GPKGTileSource.h"
#import "GPkgTestConfig.h"
#import "GPKGGeoPackageFactory.h"
#import "GPKGStandardFormatTileRetriever.h"
#import "MaplyCoordinateSystem.h"


@implementation GPKGTileSource {
    GPKGGeoPackage *_geoPackage;
    GPKGStandardFormatTileRetriever *_retriever;
    GPKGTileDao *_tileDao;
    MaplyCoordinateSystem *_coordSys;
    NSMutableDictionary *_tileOffsets;
    int _tileSize;
    
}

- (id)initWithGeoPackage:(GPKGGeoPackage *)geoPackage tableName:(NSString *)tableName {
    self = [super init];
    if (self) {
        _geoPackage = geoPackage;
        _tileDao = [_geoPackage getTileDaoWithTableName:tableName];
        
        if (!_tileDao || !_tileDao.tileMatrixSet || !_tileDao.tileMatrixSet.srsId) {
            NSLog(@"GPKGTileSource: Error accessing Tile DAO.");
            return nil;
        }
        
        GPKGTileMatrixSet *tileMatrixSet = _tileDao.tileMatrixSet;
        
        GPKGSpatialReferenceSystemDao * srsDao = [_geoPackage getSpatialReferenceSystemDao];
        GPKGSpatialReferenceSystem * srs = (GPKGSpatialReferenceSystem *)[srsDao queryForIdObject:tileMatrixSet.srsId];
        if (!srs || !srs.organization || !srs.organizationCoordsysId) {
            NSLog(@"GPKGTileSource: Error accessing SRS.");
            return nil;
        }
        if (![srs.organization isEqualToString:@"EPSG"]) {
            NSLog(@"GPKGTileSource: Unexpected SRS organization.");
            return nil;
        }
        
        
        double projMinX, projMaxY;
        
        if ([srs.organizationCoordsysId isEqualToNumber:@(4326)]) {
            NSLog(@"srs is EPSG 4326");
            projMinX = -180.0;
            projMaxY = 180.0;
            
            MaplyProj4CoordSystem *cs = [[MaplyProj4CoordSystem alloc] initWithString:@"+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs"];
            [cs setBounds:MaplyBoundingBoxMakeWithDegrees(-180.0, -180, 180.0, 180.0)];
            _coordSys = cs;
        } else if ([srs.organizationCoordsysId isEqualToNumber:@(3857)]) {
            NSLog(@"srs is EPSG 3857");
            projMinX = -20037508.3427892;
            projMaxY = 20037508.3427892;
            _coordSys = [[MaplySphericalMercator alloc] initWebStandard];
            

        } else {
            NSLog(@"GPKGTileSource: Unexpected SRS.");
            return nil;
        }
        
        _retriever = [[GPKGStandardFormatTileRetriever alloc] initWithTileDao:_tileDao];
        
        GPKGBoundingBox * gpkgBBox = [tileMatrixSet getBoundingBox];
        
        NSLog(@"bbox %f %f %f %f",
              gpkgBBox.minLongitude.doubleValue,
              gpkgBBox.minLatitude.doubleValue,
              gpkgBBox.maxLongitude.doubleValue,
              gpkgBBox.maxLatitude.doubleValue);
        
        _tileOffsets = [NSMutableDictionary dictionary];
        int n = -1;
        for (int z=_tileDao.minZoom; z<=_tileDao.maxZoom; z++) {
            GPKGTileMatrix *tileMatrix = [_tileDao getTileMatrixWithZoomLevel:z];
            
            if (tileMatrix.tileWidth.intValue != tileMatrix.tileHeight.intValue) {
                NSLog(@"GPKGTileSource: Tile widths and heights must be equal.");
                return nil;
            }
            if (n == -1) {
                n = tileMatrix.tileWidth.intValue;
                if (!(n>0 && ((n & (n-1)) == 0))) {
                    NSLog(@"GPKGTileSource: Tile size must be positive power of 2.");
                    return nil;
                }
            } else if (n != tileMatrix.tileWidth.intValue) {
                NSLog(@"GPKGTileSource: Tile sizes must be consistent.");
                return nil;
            }
            
            
            double xSridUnitsPerTile = n * tileMatrix.pixelXSize.doubleValue;
            double ySridUnitsPerTile = n * tileMatrix.pixelYSize.doubleValue;
            double xOffset = (tileMatrixSet.minX.doubleValue - projMinX) / xSridUnitsPerTile;
            double yOffset = (projMaxY - tileMatrixSet.maxY.doubleValue ) / ySridUnitsPerTile;
            NSLog(@"units per tile %f %f", xSridUnitsPerTile, ySridUnitsPerTile);
            NSLog(@"min x y %f %f", tileMatrixSet.minX.doubleValue, tileMatrixSet.minY.doubleValue);
            NSLog(@"offset %i %f %f", z, xOffset, yOffset);
            _tileOffsets[@(z)] = @[@((int)round(xOffset)), @((int)round(yOffset))];
            
            
        }
        if (n == -1) {
            NSLog(@"GPKGTileSource: No valid zoom levels found.");
            return nil;
        }
        _tileSize = n;
        
        
    }
    return self;
}

- (bool)tileIsLocal:(MaplyTileID)tileID frame:(int)frame {
    return true;
}

- (int)tileSize {
    return _tileSize;
}

- (int)minZoom {
    return _tileDao.minZoom;
}

- (int)maxZoom {
    return _tileDao.maxZoom;
}

- (nonnull MaplyCoordinateSystem *)coordSys {
    return _coordSys;
}

- (void)startFetchLayer:(id __nonnull)layer tile:(MaplyTileID)tileID {
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                   ^{
                       
                       MaplyQuadImageTilesLayer *quadLayer = (MaplyQuadImageTilesLayer *)layer;

                       NSArray *offsets = _tileOffsets[@(tileID.level)];
                       int xOffset = ((NSNumber *)offsets[0]).intValue;
                       int yOffset = ((NSNumber *)offsets[1]).intValue;
                       
                       int newX = tileID.x - xOffset;
                       int newY = ((1 << tileID.level) - tileID.y - 1) - yOffset;
                       
                       NSLog(@"fetch tile %i %i %i ; %i %i", tileID.level, tileID.x, tileID.y, newX, newY);
                       GPKGGeoPackageTile *gpkgTile = [_retriever getTileWithX:newX andY:newY andZoom:tileID.level];

                       dispatch_async(dispatch_get_main_queue(),
                                      ^{
                                           if (gpkgTile) {
                                               [quadLayer loadedImages:[gpkgTile data] forTile:tileID];
                                           } else {
                                               [quadLayer loadError:nil forTile:tileID];
                                           }
                                      });
                   });
}





@end
