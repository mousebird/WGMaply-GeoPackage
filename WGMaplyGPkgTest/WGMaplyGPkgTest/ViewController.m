//
//  ViewController.m
//  WGMaplyGPkgTest
//
//  Created by Ranen Ghosh on 2016-07-07.
//  Copyright © 2016 mousebird consulting. All rights reserved.
//

#import "ViewController.h"
#import "GPkgTestConfig.h"
#import "GPKGGeoPackageFactory.h"
#import "GPKGTileSource.h"
#import "MaplyWMSTileSource.h"

@interface ViewController ()

@end

@implementation ViewController {
    WhirlyGlobeViewController *globeVC;
    MaplyViewController *mapVC;
    MaplyBaseViewController *theViewC;
    
    GPKGGeoPackageManager *_manager;
    GPKGGeoPackage *_geoPackage;

    
    GPKGTileSource *_gpkgTileSource;
    MaplyQuadImageTilesLayer *_imageLayer;
    
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *gpkgFilename;
    NSString *gpkgTablename;
    
    if (gpkgTestMode == kDNCSanDiegoTest) {
        gpkgFilename = @"dnc-sandiego";
        gpkgTablename = @"DNCBASEMAP12_16";
    } else if (gpkgTestMode == kERDCWhitehorseTest) {
        gpkgFilename = @"ERDC_Whitehorse_GeoPackage";
        gpkgTablename = @"WhiteHorse";
    } else if (gpkgTestMode == kRiverTilesTest) {
        gpkgFilename = @"rivers";
        gpkgTablename = @"rivers_tiles";
    }
    
    _manager = [GPKGGeoPackageFactory getManager];
    @try {
        [_manager importGeoPackageFromUrl:[[NSBundle mainBundle] URLForResource:gpkgFilename withExtension:@"gpkg"] withName:gpkgFilename];
    } @catch (NSException *exception) {
        NSLog(@"Exception in importGeoPackageFromUrl %@", exception);
    }
    _geoPackage = [_manager open:gpkgFilename];
    _gpkgTileSource = [[GPKGTileSource alloc] initWithGeoPackage:_geoPackage tableName:gpkgTablename];

    
    if (gpkgTestDoGlobe) {
        globeVC = [[WhirlyGlobeViewController alloc] init];
        theViewC = globeVC;
        globeVC.delegate = self;
        
        [self.view addSubview:globeVC.view];
        globeVC.view.frame = self.view.bounds;
        [self addChildViewController:globeVC];
    } else {
        mapVC = [[MaplyViewController alloc] initWithMapType:MaplyMapTypeFlat];
        theViewC = mapVC;
        mapVC.coordSys = _gpkgTileSource.coordSys;
        mapVC.delegate = self;
        
        [self.view addSubview:mapVC.view];
        mapVC.view.frame = self.view.bounds;
        [self addChildViewController:mapVC];
    }
    
    
    
    // Start out over San Diego
    
    MaplyCoordinate startCoord;
    if (gpkgTestMode == kDNCSanDiegoTest) {
        //startCoord = MaplyCoordinateMakeWithDegrees(-117.1625,32.715);
        if (gpkgTestSanDiegoForce3857)
            startCoord = MaplyCoordinateMakeWithDegrees(-117.1625,49.55);
        else {
            //startCoord = MaplyCoordinateMakeWithDegrees(-117.1625,28.6);
            //startCoord = MaplyCoordinateMakeWithDegrees(-117.1625,57.0);
            startCoord = MaplyCoordinateMakeWithDegrees(-117.1625,32.715);
        }
    } else if (gpkgTestMode == kERDCWhitehorseTest) {
        startCoord = MaplyCoordinateMakeWithDegrees(-135.18,60.85);
    } else if (gpkgTestMode == kRiverTilesTest) {
        startCoord = MaplyCoordinateMakeWithDegrees( -74.0059,40.7127);
    }
    
    if (gpkgTestDoGlobe)
        [globeVC setPosition:startCoord height:0.002];
    else
        [mapVC setPosition:startCoord height:0.002];
    
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)  objectAtIndex:0];
    if (gpkgTestMode == kERDCWhitehorseTest || gpkgTestMode == kRiverTilesTest) {
        // Add CartoDB positron basemap
        
        MaplyRemoteTileSource *tileSource = [[MaplyRemoteTileSource alloc] initWithBaseURL:@"http://positron.basemaps.cartocdn.com/light_all/{z}/{x}/{y}" ext:@"png" minZoom:0 maxZoom:18];
        tileSource.cacheDir = [NSString stringWithFormat:@"%@/positron/",cacheDir];
        MaplyQuadImageTilesLayer *layer = [[MaplyQuadImageTilesLayer alloc] initWithCoordSystem:tileSource.coordSys tileSource:tileSource];
        layer.drawPriority = kMaplyImageLayerDrawPriorityDefault;
        layer.handleEdges = true;
        [theViewC addLayer:layer];
    } else if (gpkgTestMode == kDNCSanDiegoTest) {

        NSString *weatherDataType = @"surface_pressure";
        
        // Spherical mercator tile sets
        //                NSString *coordSysStr = @"mercator";
        //                MaplyCoordinateSystem *coordSys = [[MaplySphericalMercator alloc] initWebStandard];
        //                NSString *baseURL = @"http://weather.openportguide.de/demo";
        
        // Plate Carree tile sets
        NSString *coordSysStr = @"geo";
        MaplyBoundingBox geobbox;
        geobbox.ll = MaplyCoordinateMakeWithDegrees(-180, -90);
        geobbox.ur = MaplyCoordinateMakeWithDegrees(180, 90);
        MaplyCoordinateSystem *coordSys = [[MaplyPlateCarree alloc] initWithBoundingBox:geobbox];
        NSString *baseURL = @"http://weather.openportguide.com/tiles/actual/";
        
        NSString *urlStr = [NSString stringWithFormat:@"%@/%@/5/{z}/{x}/{y}",baseURL,weatherDataType];
        MaplyRemoteTileSource *tileSource = [[MaplyRemoteTileSource alloc] initWithBaseURL:urlStr ext:@"png" minZoom:1 maxZoom:7];
        tileSource.coordSys = coordSys;
        tileSource.cacheDir = [NSString stringWithFormat:@"%@/%@_%@/",cacheDir,weatherDataType,coordSysStr];
        ((MaplyRemoteTileInfo *)tileSource.tileInfo).cachedFileLifetime = 3 * 60 * 60; // invalidate OWM data after three hours
        MaplyQuadImageTilesLayer *weatherLayer = [[MaplyQuadImageTilesLayer alloc] initWithCoordSystem:tileSource.coordSys tileSource:tileSource];
        weatherLayer.coverPoles = false;
        weatherLayer.drawPriority = kMaplyImageLayerDrawPriorityDefault+20;
        weatherLayer.handleEdges = false;
        weatherLayer.drawPriority = kMaplyImageLayerDrawPriorityDefault+50;
        
        [theViewC addLayer:weatherLayer];
    }
    
    
    //_imageLayer = [[MaplyQuadImageTilesLayer alloc] initWithCoordSystem:[[MaplySphericalMercator alloc] initWebStandard] tileSource:_gpkgTileSource];
    _imageLayer = [[MaplyQuadImageTilesLayer alloc] initWithCoordSystem:_gpkgTileSource.coordSys tileSource:_gpkgTileSource];
    _imageLayer.numSimultaneousFetches = 2;
    _imageLayer.color = [UIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.5];
    _imageLayer.drawPriority = kMaplyImageLayerDrawPriorityDefault + 100;
    
    [theViewC addLayer:_imageLayer];
    
}

- (void)globeViewController:(WhirlyGlobeViewController *__nonnull)viewC didTapAt:(MaplyCoordinate)coord {
    
     NSLog(@"didTapAt %f %f", coord.x * RAD_TO_DEG, coord.y * RAD_TO_DEG);
}

- (void)maplyViewController:(MaplyViewController *__nonnull)viewC didTapAt:(MaplyCoordinate)coord {

    NSLog(@"didTapAt %f %f", coord.x * RAD_TO_DEG, coord.y * RAD_TO_DEG);
}

@end
