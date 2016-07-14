//
//  GPKGUrlTileGenerator.m
//  geopackage-ios
//
//  Created by Brian Osborn on 6/18/15.
//  Copyright (c) 2015 NGA. All rights reserved.
//

#import "GPKGUrlTileGenerator.h"
#import "GPKGProperties.h"
#import "GPKGPropertyConstants.h"
#import "GPKGTileBoundingBoxUtils.h"
#import "GPKGIOUtils.h"
#import "GPKGProjectionFactory.h"

@interface GPKGUrlTileGenerator ()

@property (nonatomic, strong) NSString *tileUrl;
@property (nonatomic) BOOL urlHasXYZ;
@property (nonatomic) BOOL urlHasBoundingBox;

@end

@implementation GPKGUrlTileGenerator

-(instancetype) initWithGeoPackage: (GPKGGeoPackage *) geoPackage andTableName: (NSString *) tableName andTileUrl: (NSString *) tileUrl andMinZoom: (int) minZoom andMaxZoom: (int) maxZoom andBoundingBox: (GPKGBoundingBox *) boundingBox andProjection: (GPKGProjection *) projection{
    self = [super initWithGeoPackage:geoPackage andTableName:tableName andMinZoom:minZoom andMaxZoom:maxZoom andBoundingBox:boundingBox andProjection:projection];
    if(self != nil){
        
        self.tileUrl = [GPKGIOUtils decodeUrl:tileUrl];
        
        self.urlHasXYZ = [self hasXYZ:tileUrl];
        self.urlHasBoundingBox = [self hasBoundingBox:tileUrl];

        if(!self.urlHasXYZ && !self.urlHasBoundingBox){
            [NSException raise:@"Invalid URL" format:@"URL does not contain x,y,z or bounding box variables: %@", tileUrl];
        }
    }
    return self;
}

-(BOOL) hasXYZ: (NSString *) url{
    
    NSString * replacedUrl = [self replaceXYZWithUrl:url andZ:0 andX:0 andY:0];
    BOOL hasXYZ = ![replacedUrl isEqualToString:url];
    
    return hasXYZ;
}

-(NSString *) replaceXYZWithUrl: (NSString *) url andZ: (int) z andX: (int) x andY: (int) y{
    
    url = [url stringByReplacingOccurrencesOfString:
           [GPKGProperties getValueOfBaseProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE andProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE_Z]
                                         withString:[NSString stringWithFormat:@"%d",z]];
    url = [url stringByReplacingOccurrencesOfString:
           [GPKGProperties getValueOfBaseProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE andProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE_X]
                                         withString:[NSString stringWithFormat:@"%d",x]];
    url = [url stringByReplacingOccurrencesOfString:
           [GPKGProperties getValueOfBaseProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE andProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE_Y]
                                         withString:[NSString stringWithFormat:@"%d",y]];
    return url;
}

-(BOOL) hasBoundingBox: (NSString *) url{
    
    NSString * replacedUrl = [self replaceBoundingBoxWithUrl:url andBoundingBox:self.boundingBox];
    BOOL hasBoundingBox = ![replacedUrl isEqualToString:url];
    
    return hasBoundingBox;
}

-(NSString *) replaceBoundingBoxWithUrl: (NSString *) url andZ: (int) z andX: (int) x andY: (int) y{
    
    GPKGBoundingBox * boundingBox = [GPKGTileBoundingBoxUtils getProjectedBoundingBoxWithProjection:self.projection andX:x andY:y andZoom:z];
    
    url = [self replaceBoundingBoxWithUrl:url andBoundingBox:boundingBox];
    
    return url;
}

-(NSString *) replaceBoundingBoxWithUrl: (NSString *) url andBoundingBox: (GPKGBoundingBox *) boundingBox{
    
    url = [url stringByReplacingOccurrencesOfString:
           [GPKGProperties getValueOfBaseProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE andProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE_MIN_LAT]
                                         withString:[boundingBox.minLatitude stringValue]];
    url = [url stringByReplacingOccurrencesOfString:
           [GPKGProperties getValueOfBaseProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE andProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE_MAX_LAT]
                                         withString:[boundingBox.maxLatitude stringValue]];
    url = [url stringByReplacingOccurrencesOfString:
           [GPKGProperties getValueOfBaseProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE andProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE_MIN_LON]
                                         withString:[boundingBox.minLongitude stringValue]];
    url = [url stringByReplacingOccurrencesOfString:
           [GPKGProperties getValueOfBaseProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE andProperty:GPKG_PROP_TILE_GENERATOR_VARIABLE_MAX_LON]
                                         withString:[boundingBox.maxLongitude stringValue]];
    
    return url;
}

-(void) preTileGeneration{

}

-(NSData *) createTileWithZ: (int) z andX: (int) x andY: (int) y{
    
    NSString * zoomUrl = self.tileUrl;
    
    // Replace x, y, and z
    if(self.urlHasXYZ){
        int yRequest = y;
        
        // If TMS, flip the y value
        if(self.tms){
            yRequest = [GPKGTileBoundingBoxUtils getYAsOppositeTileFormatWithZoom:z andY:y];
        }
        
        zoomUrl = [self replaceXYZWithUrl:zoomUrl andZ:z andX:x andY:yRequest];
    }
    
    // Replace bounding box
    if(self.urlHasBoundingBox){
        zoomUrl = [self replaceBoundingBoxWithUrl:zoomUrl andZ:z andX:x andY:y];
    }
    
    NSURL * url =  [NSURL URLWithString:zoomUrl];
    
    NSData * data = [NSData dataWithContentsOfURL:url];
    
    return data;
}

@end
